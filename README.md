# NAME
krenewd - Kerberos ticket refresh daemon

# SYNOPSIS
krenewd [OPTION]...

# DESCRIPTION
**krenewd** is a daemon designed to automatically renew Kerberos tickets. It monitors a session or process ID and renews Kerberos tickets at defined intervals while the process or session is alive. It can utilize a keytab file to automatically acquire a ticket if no ticket is available at startup.

# OPTIONS
Most options can also be configure via environment variables. This can be useful for debugging or when defining global configuration defaults. The environment variables use the same values as the command-line options. However command-line options take precedence over environment variables. Flags can be unset via `--option-name=false` (only the long form is supported in this case).  

**-h, --help**
Display the help text and exit.

**-V, --version**
Show version and copyright information, then exit.

**-s, --session-id=\<string\>** (*XDG_SESSION_ID*)
Specify the login session ID to monitor, defaulting to the current session as determined by `XDG_SESSION_ID`.

**-m, --master=\<pid\>** (*KRENEWD_MASTER*)
Set the process ID to monitor. Specify '0' to disable monitoring. If neither process nor session IDs are provided, the parent process is monitored by default. Overrides `--session-id`.

**-i, --interval=\<seconds\>** (*KRENEWD_INTERVAL*)
Define the time interval between ticket renewals, in seconds. Default is 200 seconds.

**-d, --destroy** (*KRENEWD_DESTROY*)
Destroy the ticket on exit but only if the lock was acquired during the session or if 'no-lock' was specified.

**-p, --no-passive** (*KRENEWD_NOPASSIVE*)
Exit immediately if the lock cannot be acquired, instead of waiting.

**-f, --foreground** (*KRENEWD_FOREGROUND*)
Run the daemon in the foreground, preventing it from forking into the background.

**-v, --verbose** (*KRENEWD_VERBOSE*)
Enable verbose output to give more insights into what krenewd is doing.

**-t, --trace** (*KRENEWD_TRACE*)
Enable trace output from kinit, useful for debugging Kerberos authentication issues.

**-l, --no-lock** (*KRENEWD_NOLOCK*)
Allow multiple instances of the daemon to run simultaneously by ignoring the singleton lock.

**-b, --no-block** (*KRENEWD_NOBLOCK*)
Proceed without waiting if the initial ticket acquisition/refresh fails.  
By default, krenewd blocks in foreground until it managed to acquire/refresh the ticket for the given principal. If no-block is specified, it will **try only once** and then fork into background. This is important for login shells to not block-out the user. However it still provides a ticket under normal circumstances for folowing processes. This is important in cases when the ticket is used immediately after starting krenewd - for example when the home-folder is located on a kerberized NFS share.

**-k, --keytab=\<existing path\>** (*KRENEWD_KEYTAB*)
Specify a custom path for the keytab file. If not provided, the keytab file will be auto-detected based on the following search order:  
	1. `/etc/$USER.keytab`  
	2. `$HOME/.krenewd/krb5.keytab`  
	3. `$HOME/$USER.keytab`  
	4. `$HOME/krb5.keytab`  
	5. `$HOME/.krb5.keytab`  
	6. `/etc/krb5.keytab`  
	
**-J, --journal** (*KRENEWD_JOURNAL*)
When specified krenewd will send all log messages to the systemd journal in addition to logging to stderr.  
krenewd uses structured logging. The following fields will be added to each message:  
	- **PID** (krenewd's own process ID)  
	- **PPID** (The ID of the parent process that started krenewd)  
	- **SESSION** (The systemd session ID)  
	- **MASTER_PID** (The ID of the proccess that krenewd is monitoring)  
	- **PRINCIPAL** (The pricipal of the ticket that krenewd will try to acquire/refresh)  
	- **USER** (The linux user account name under which krenewd is running)  

	*Keep in mind that some fields may be empty during early process startup.*

# ENVIRONMENT VARIABLES
For details refer the command-line options above.  
Boolean variables can take the folloing values: `true`/`false`, `yes`/`no`, `enabled`/`disabled`, `1`/`0`.  
- **XDG_SESSION_ID** (string)  
- **KRENEWD_INTERVAL** (integer)  
- **KRENEWD_DESTROY** (boolean)  
- **KRENEWD_NOPASSIVE** (boolean)  
- **KRENEWD_FOREGROUND** (boolean)  
- **KRENEWD_VERBOSE** (boolean)  
- **KRENEWD_TRACE** (boolean)  
- **KRENEWD_NOLOCK** (boolean)  
- **KRENEWD_NOBLOCK** (boolean)  
- **KRENEWD_KEYTAB** (filename)  
- **KRENEWD_JOURNAL** (boolean)  

# EXAMPLES

- **Shell profile/bachrc**  
	To run the daemon from your profile or bashrc, make sure to include the `--no-block` and `--journal` options:  
		`krenewd --no-block --verbose --journal >/dev/null 2>&1 </dev/null`  
	You can view the log messages via:  
		`journalctl --user _COMM=krenewd`

- **Daemon accounts**  
	To enable the service for a specific daemon user:  
		`systemctl enable --now krenewd@USERNAME.service`  
	Replace `USERNAME` with the name of the daemon user.
   
- **PAM integration**  
	To enable krenewd automatically via PAM on login add the following to `/etc/pam.d/common-session`:  
		`session optional pam_exec.so seteuid type=open_session /usr/bin/krenewd.pam --no-block --verbose --journal`  

# AUTHOR
Written by Simon Brennecke.

# COPYRIGHT
Copyright (C) 2024 Simon Brennecke, licensed under GNU GPL version 3 or later.

# SEE ALSO
*kerberos*(7), *kinit*(1), *klist*(1), *kdestroy*(1), *journalctl*(1)

# NOTES
This manual page was written for `krenewd` version `32.xxxxxxx`. The behavior may differ in other versions.
