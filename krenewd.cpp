#include <el1/el1.cpp>
#include <unistd.h>
#include <sys/types.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <pwd.h>

using namespace el1::io::types;
using namespace el1::io::collection::list;
using namespace el1::io::text::string;
using namespace el1::io::text::encoding::utf8;
using namespace el1::error;
using namespace el1::system::cmdline;
using namespace el1::system::time;
using namespace el1::system::task;

static bool verbose = false;

static bool AcquireNewTicket(const TString& principal, const TPath& keytab)
{
	if(verbose) fprintf(stderr, "requesting new ticket from KDC ... ");
	const bool status = TProcess::ExecuteWithStatus("/usr/bin/kinit", { "-k", "-t", keytab, principal }) == 0;
	if(verbose) fprintf(stderr, status ? "OK\n" : "FAILED\n");
	return status;
}

static bool RenewTicket(const TString& principal)
{
	if(verbose) fprintf(stderr, "renewing ticket ... ");
	const bool status = TProcess::ExecuteWithStatus("/usr/bin/kinit", { "-R", principal }) == 0;
	if(verbose) fprintf(stderr, status ? "OK\n" : "FAILED\n");
	return status;
}

static bool IsProcessAlive(const pid_t pid)
{
	return pid == 0 ? true : (kill(pid, 0) == 0);
}

static void CloseStdio()
{
	// close stdin and stdout
	close(0);
	close(1);
}

static bool TryAcquireLock(TFile& lock_file)
{
	if(verbose) fprintf(stderr, "trying to acquire lock ... ");
	if(flock(lock_file.Handle(), LOCK_EX|LOCK_NB) == -1)
	{
		if(errno == EWOULDBLOCK)
		{
			if(verbose) fprintf(stderr, "already taken\n");
			return false;
		}
		EL_THROW(TSyscallException, errno);
	}
	else
	{
		if(verbose) fprintf(stderr, "acquired lock\n");
		return true;
	}
}

int main(int argc, char* argv[])
{
	int exit_code = 0;
	bool destroy = false;
	bool lock_acquired = false;
	TString principal;
	TTime renew_interval;
	bool foreground = true;
	bool no_passive = false;
	bool no_lock = false;
	bool trace = false;
	pid_t master_pid = -1;

	try
	{
		{
			s64_t i = 10 * 60 / 3;
			s64_t pid = EL_SYSERR(getppid());
			ParseCmdlineArguments(argc, argv,
				TIntegerArgument(&pid, 'm', "master", "", true, false, "PID of the master process to monitor (default parent). Set to '0' to disable monitor."),
				TIntegerArgument(&i, 'i', "interval", "KRENEWD_INTERVAL", true, false, "time interval between renewing the ticket"),
				TFlagArgument(&destroy, 'd', "destroy", "KRENEWD_DESTROY", "destroy ticket on exit (but only when we acquired the lock)"),
				TFlagArgument(&no_passive, 'p', "no-passive", "KRENEWD_NOPASSIVE", "exit immediately if the lock cannot be acquired"),
				TFlagArgument(&foreground, 'f', "foreground", "KRENEWD_FOREGROUND", "do not fork into background"),
				TFlagArgument(&::verbose, 'v', "verbose", "KRENEWD_VERBOSE", "print status messages"),
				TFlagArgument(&trace, 't', "trace", "KRENEWD_TRACE", "show trace output from kinit"),
				TFlagArgument(&no_lock, 'l', "no-lock", "KRENEWD_NOLOCK", "ignore the singelton lock")
			);
			renew_interval = TTime(i, 0);
			master_pid = pid;
		}

		if(trace)
			EnvironmentVariables().Set("KRB5_TRACE", "/dev/stderr");

		mlockall(MCL_CURRENT|MCL_FUTURE);
		CloseStdio();
		EL_SYSERR(umask(0177));
		const uid_t uid = EL_SYSERR(getuid());
		struct passwd* pw = getpwuid(uid);
		EL_ERROR(pw == nullptr, TException, TString::Format("unable to lookup username for current user with UID=%d in password database", uid));
		const TString username = pw->pw_name;
		TString fqdn = TFile("/etc/hostname").Pipe().Transform(TUTF8Decoder()).Collect();
		fqdn.Trim();
		principal = uid == 0 ? fqdn : username;
		const TPath keytab = uid == 0 ? TString("/etc/krb5.keytab") : TString::Format("/etc/%s.keytab", username);
		TFile lock_file(TString::Format("/tmp/krenewd-%s-%s.lock", username, principal), TAccess::RW, ECreateMode::NX);
		lock_acquired = no_lock || TryAcquireLock(lock_file);

		if(no_passive && !lock_acquired)
		{
			if(verbose) fprintf(stderr, "lock already taken - exiting\n");
			throw shutdown_t();
		}

		if(lock_acquired)
		{
			if(verbose) fprintf(stderr, "trying to acquire initial ticket ... \n");
			while(! AcquireNewTicket(principal, keytab))
				TFiber::Sleep(5);
		}

		if(foreground || EL_SYSERR(fork()) == 0)
		{
			try
			{
				TFiber::Sleep(renew_interval);
				while(IsProcessAlive(master_pid))
				{
					if(!lock_acquired)
						lock_acquired = TryAcquireLock(lock_file);

					if(lock_acquired)
					{
						if(!RenewTicket(principal))
							AcquireNewTicket(principal, keytab);
					}

					TFiber::Sleep(renew_interval);
				}

				if(verbose) fprintf(stderr, "master process died - exiting\n");
			}
			catch(shutdown_t)
			{
				if(verbose) fprintf(stderr, "received shutdown signal - exiting\n");
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

	if(lock_acquired && destroy)
		TProcess::ExecuteWithStatus("/usr/bin/kdestroy", { "-p", principal });

	return exit_code;
}
