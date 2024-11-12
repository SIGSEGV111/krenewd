/*
	krenewd: A daemon for automatically refreshing Kerberos tickets.
	Copyright (C) 2024 Simon Brennecke
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
	GNU General Public License for more details.
	You should have received a copy of the GNU General Public License
	along with this program. If not, see <https://www.gnu.org/licenses/>.
*/

#include <el1/el1.cpp>
#include <systemd/sd-login.h>
#include <systemd/sd-journal.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <pwd.h>
#include <krb5.h>

using namespace el1::io::types;
using namespace el1::io::collection::list;
using namespace el1::io::text::string;
using namespace el1::io::text::encoding::utf8;
using namespace el1::io::text::terminal;
using namespace el1::error;
using namespace el1::system::cmdline;
using namespace el1::system::time;
using namespace el1::system::task;

static bool verbose = false;
static s64_t master_pid = -1;
static TString session_id;
static TString principal;
static TString username;
static bool journal = false;

static TString GetKerberosTicketCache()
{
	krb5_context context;
	krb5_error_code retval;
	EL_ERROR(retval = krb5_init_context(&context) != 0, TException, TString::Format("Error initializing Kerberos context: %d", retval));

	try
	{
		krb5_ccache cache;
		EL_ERROR(retval = krb5_cc_default(context, &cache) != 0, TException, TString::Format("Error getting default credential cache: %s", krb5_get_error_message(context, retval)));

		try
		{
			const char* cstr_cache_name = krb5_cc_get_name(context, cache);
			EL_ERROR(cstr_cache_name == nullptr, TException, TString::Format("Error retrieving ticket cache name: %s", krb5_get_error_message(context, retval)));

			const char* cstr_cache_type = krb5_cc_get_type(context, cache);
			EL_ERROR(cstr_cache_type == nullptr, TException, TString::Format("Error retrieving ticket cache type: %s", krb5_get_error_message(context, retval)));
			
			TString cache_name = cstr_cache_name;
			TString cache_type = cstr_cache_type;
			
			if(cache_type == "DIR")
			{
				TPath p = cache_name;
				p.Truncate(1);
				cache_name = p;
			}

			TString cache_fullname = TString::Format("%s%s", cache_type, cache_name);
			krb5_cc_close(context, cache);
			krb5_free_context(context);

			return cache_fullname;
		}
		catch(...)
		{
			krb5_cc_close(context, cache);
			throw;
		}
	}
	catch(...)
	{
		krb5_free_context(context);
		throw;
	}
}

static void LogMessage(TString msg)
{
	if(journal)
		sd_journal_send(
			(TString("MESSAGE=") + msg).MakeCStr().get(),
			"PRIORITY=%i", LOG_INFO,
			"PID=%d", getpid(),
			"PPID=%d", getppid(),
			"SESSION=%s", session_id.MakeCStr().get(),
			"MASTER_PID=%d", master_pid,
			"PRINCIPAL=%s", principal.MakeCStr().get(),
			"USER=%s", username.MakeCStr().get(),
			nullptr
		);

	term.Print(std::move(msg));
}

template<typename ... R>
static void LogMessage(TString format, R&& ... r)
{
	LogMessage(TString::Format(std::move(format), std::forward<R>(r) ...));
}

static usys_t DJB2(const TString& str) {
	usys_t hash = 5381;
	for (auto c : str.chars) {
		hash = ((hash << 5) + hash) + c.code; // hash * 33 + c
	}
	return hash;
}

static bool AcquireNewTicket(const TString& principal, const TPath& keytab)
{
	EL_ERROR(keytab.IsEmpty(), TException, "no keytab specified/found - cannot acquire new ticket");
	if(verbose) LogMessage("requesting new ticket from KDC ... ");
	TString stdout, stderr;
	const bool status = TProcess::ExecuteWithStatus("/usr/bin/kinit", { "-k", "-t", keytab, principal }, nullptr, &stdout, &stderr) == 0;
	if(verbose) LogMessage(status ? "OK\n" : "FAILED\n");
	if(verbose || !status) LogMessage("stdout:\n%s\nstderr:\n%s\n", stdout, stderr);
	return status;
}

static bool IsSessionAlive(const TString& session_id)
{
	char* state = nullptr;
	if(sd_session_get_state(session_id.MakeCStr().get(), &state) < 0)
		return false;
	const bool b = strcmp(state, "online") == 0 || strcmp(state, "active") == 0;
	free(state);
	return b;
}

static bool RenewTicket(const TString& principal)
{
	if(verbose) LogMessage("renewing ticket ... ");
	const bool status = TProcess::ExecuteWithStatus("/usr/bin/kinit", { "-R", principal }) == 0;
	if(verbose) LogMessage(status ? "OK\n" : "FAILED\n");
	return status;
}

static bool IsProcessAlive(const pid_t pid)
{
	return kill(pid, 0) == 0;
}

static bool IsAlive(const pid_t master_pid, const TString& session_id)
{
	if(session_id.Length() > 0)
		return IsSessionAlive(session_id);

	if(master_pid > 0)
		return IsProcessAlive(master_pid);

	return true;
}

static void CloseStdio()
{
	// close stdin and stdout

	close(0);
	EL_SYSERR(dup2(2, 1));

	el1::io::text::terminal::stdin.handle.Close();
	el1::io::text::terminal::stdout.handle = el1::io::text::terminal::stderr.handle;
}

static bool TryAcquireLock(TFile& lock_file)
{
	if(verbose) LogMessage("trying to acquire lock ... ");
	if(flock(lock_file.Handle(), LOCK_EX|LOCK_NB) == -1)
	{
		if(errno == EWOULDBLOCK)
		{
			if(verbose) LogMessage("already taken\n");
			return false;
		}
		EL_THROW(TSyscallException, errno);
	}
	else
	{
		if(verbose) LogMessage("OK\n");
		return true;
	}
}

static TPath FindKeytab(const TString& username, const TPath& home_dir)
{
	TPath p;

	if( (p = TString::Format("/etc/%s.keytab", username)).Exists() )
		return p;

	if( (p = home_dir + ".krenewd/krb5.keytab").Exists() )
		return p;

	if( (p = home_dir + TString::Format("%s.keytab", username)).Exists() )
		return p;

	if( (p = home_dir + "krb5.keytab").Exists() )
		return p;

	if( (p = home_dir + ".krb5.keytab").Exists() )
		return p;

	if( username == "root" && (p = "/etc/krb5.keytab").Exists() )
		return p;

	return TPath();
}

static void ShowVersion()
{
	std::cerr<<
		"krenewd (Kerberos ticket refresh daemon) - " VERSION "\n"
		"Copyright (C) 2024 Simon Brennecke\n"
		"License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.\n"
		"This is free software: you are free to change and redistribute it.\n"
		"There is NO WARRANTY, to the extent permitted by law.\n";
}

int main(int argc, char* argv[])
{
	bool destroy = false;
	bool lock_acquired = false;
	bool foreground = true;
	bool no_passive = false;
	bool no_lock = false;
	bool no_block = false;
	bool trace = false;
	int exit_code = 0;
	TTime renew_interval;

	try
	{
		TPath keytab;
		{
			s64_t i = 10 * 60 / 3;
			bool show_version = false;

			{
				char* _session_id = nullptr;
				if(sd_pid_get_session(getpid(), &_session_id) >= 0)
				{
					session_id = _session_id;
					free(_session_id);
				}
			}

			ParseCmdlineArguments(argc, argv,
				TFlagArgument(&show_version, 'V', "version", "", "Show copyright and version information and exit."),
				TStringArgument(&session_id, 's', "session-id", "XDG_SESSION_ID", true, false, "Specify the login session ID to monitor. Default is the current session. (XDG_SESSION_ID)"),
				TIntegerArgument(&master_pid, 'm', "master", "KRENEWD_MASTER", true, false, "Specify the process ID to monitor. A value of '0' disables the monitoring. If no process & session IDs are specified, then the default is to monitor the parent process. This setting, if specified, overrules 'session-id'."),
				TIntegerArgument(&i, 'i', "interval", "KRENEWD_INTERVAL", true, false, "Set the time interval (in seconds) between ticket renewals. (KRENEWD_INTERVAL)"),
				TFlagArgument(&destroy, 'd', "destroy", "KRENEWD_DESTROY", "Destroy the ticket on exit, but only if the lock was acquired during the session (or 'no-lock' was specified). (KRENEWD_DESTROY)"),
				TFlagArgument(&no_passive, 'p', "no-passive", "KRENEWD_NOPASSIVE", "Exit immediately if the lock cannot be acquired. (KRENEWD_NOPASSIVE)"),
				TFlagArgument(&foreground, 'f', "foreground", "KRENEWD_FOREGROUND", "Run in the foreground; do not fork into the background. (KRENEWD_FOREGROUND)"),
				TFlagArgument(&::verbose, 'v', "verbose", "KRENEWD_VERBOSE", "Enable verbose output. (KRENEWD_VERBOSE)"),
				TFlagArgument(&trace, 't', "trace", "KRENEWD_TRACE", "Enable trace output from kinit for debugging. (KRENEWD_TRACE)"),
				TFlagArgument(&no_lock, 'l', "no-lock", "KRENEWD_NOLOCK", "Ignore the singleton lock, allowing multiple instances to run simultaneously. (KRENEWD_NOLOCK)"),
				TFlagArgument(&no_block, 'b', "no-block", "KRENEWD_NOBLOCK", "Proceed without blocking if the initial ticket acquisition fails. (KRENEWD_NOBLOCK)"),
				TPathArgument(&keytab, 'k', "keytab", "KRENEWD_KEYTAB", true, false, "Specify the keytab file to use for authentication. If not specified, the keytab will be auto-detected. (KRENEWD_KEYTAB)"),
				TFlagArgument(&journal, 'J', "journal", "KRENEWD_JOURNAL", "When specified krenewd will also send all log messages to systemd-journal *in addition* to logging to stderr' (KRENEWD_JOURNAL)"),
				TStringArgument(&principal, 'P', "principal", "KRENEWD_PRINCIPAL", true, false, "Specify the ticket principal name. Default is the linux user account name. For the root user host/fqdn@domain is used instead. (KRENEWD_PRINCIPAL)")
			);

			if(show_version)
			{
				ShowVersion();
				throw shutdown_t();
			}

			chdir("/");
			CloseStdio();
			renew_interval = TTime(i, 0);

			if(master_pid == -1 && session_id.Length() == 0)
				master_pid = EL_SYSERR(getppid());

			if(master_pid > 0)
			{
				LogMessage("monitoring process %d\n", master_pid);
				session_id = "";
			}

			if(session_id.Length() > 0 && verbose) LogMessage("monitoring session %q\n", session_id.MakeCStr().get());

			EL_ERROR(!IsAlive(master_pid, session_id), TException, "master process or session is not alive");
		}

		mlockall(MCL_CURRENT|MCL_FUTURE);
		EL_SYSERR(umask(0077));

		if(trace)
			EnvironmentVariables().Set("KRB5_TRACE", "/dev/stderr");

		const uid_t uid = EL_SYSERR(getuid());
		struct passwd* pw = getpwuid(uid);
		EL_ERROR(pw == nullptr, TException, TString::Format("unable to lookup username for current user with UID=%d in password database", uid));
		username = pw->pw_name;
		if(verbose) LogMessage("running as user %q (%d)\n", username, uid);

		const TString fqdn = TFile::ReadText("/etc/hostname");
		if(principal.Length() == 0)
			principal = uid == 0 ? TString::Format("host/%s", fqdn) : username;
		LogMessage("using principal %q\n", principal);

		const TString ticket_cache_name = GetKerberosTicketCache();
		const usys_t ticket_cache_hash = DJB2(ticket_cache_name);
		if(verbose)
			LogMessage("detected ticket-cache: %s\n", ticket_cache_name);

		if(keytab.IsEmpty())
		{
			if(verbose) LogMessage("no keytab file specified => searching ...\n");
			keytab = FindKeytab(username, pw->pw_dir);
			if(verbose && keytab.IsEmpty()) LogMessage("no keytab file found\n");
		}

		if(verbose && !keytab.IsEmpty()) LogMessage("using keytab %q\n", (const char*)keytab);

		TString username_safe = username;
		TString principal_safe = principal;
		principal_safe.Replace("/", "_");
		username_safe.Replace("/", "_");
		const TPath lock_file_path = TString::Format("/tmp/krenewd-%s-%s-%x.lock", username_safe, principal_safe, ticket_cache_hash);
		if(verbose) LogMessage("using lock-file: %q\n", lock_file_path.ToString());
		TFile lock_file(lock_file_path, TAccess::RW, ECreateMode::NX);
		lock_acquired = no_lock || TryAcquireLock(lock_file);

		if(no_passive && !lock_acquired)
		{
			if(verbose) LogMessage("lock already taken and passive mode disabled => exiting\n");
			throw shutdown_t();
		}

		if(lock_acquired)
		{
			while( !(RenewTicket(principal) || AcquireNewTicket(principal, keytab)) && !no_block )
				TFiber::Sleep(5);
		}

		if(foreground || EL_SYSERR(fork()) == 0)
		{
			if(!foreground)
				EL_SYSERR(setsid());

			try
			{
				if(verbose) LogMessage("entering normal operation\n");
				TFiber::Sleep(renew_interval);
				while(IsAlive(master_pid, session_id))
				{
					if(!lock_acquired)
						lock_acquired = TryAcquireLock(lock_file);

					if(lock_acquired)
					{
						if(!RenewTicket(principal))
							if(!keytab.IsEmpty())
								AcquireNewTicket(principal, keytab);
					}

					TFiber::Sleep(renew_interval);
				}

				if(verbose) LogMessage("master process terminated => exiting\n");
			}
			catch(shutdown_t)
			{
				if(verbose) LogMessage("received shutdown signal => exiting\n");
			}
		}
	}
	catch(shutdown_t)
	{
	}
	catch(const IException& e)
	{
		e.Print("TOP LEVEL");
		exit_code = 1;
	}

	if((lock_acquired || no_lock) && destroy)
		TProcess::ExecuteWithStatus("/usr/bin/kdestroy", { "-p", principal });

	return exit_code;
}
