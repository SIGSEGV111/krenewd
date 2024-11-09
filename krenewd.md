# NAME
krenewd - Kerberos ticket refresh daemon

# SYNOPSIS
krenewd [OPTION]...

# DESCRIPTION
**krenewd** is a daemon designed to automatically renew Kerberos tickets. It monitors specified session or process IDs and renews Kerberos tickets at defined intervals, utilizing a specified keytab file if provided. If no keytab file is specified, **krenewd** will follow an auto-detection sequence to locate an existing keytab. The keytab is only used if required —that is— if no existing ticket can be refreshed.

# OPTIONS
**-h, --help**
Display the help text and exit.

**-V, --version**
Show version and copyright information, then exit.

**-s, --session-id=\<string\>**
Specify the login session ID to monitor, defaulting to the current session as determined by `XDG_SESSION_ID`.

**-m, --master=\<pid\>**
Set the process ID to monitor. Specify '0' to disable monitoring. If neither process nor session IDs are provided, the parent process is monitored by default. Overrides `--session-id`.

**-i, --interval=\<seconds\>**
Define the time interval between ticket renewals, in seconds. Default is 200 seconds.

**-d, --destroy**
Destroy the ticket on exit but only if the lock was acquired during the session or if 'no-lock' was specified.

**-p, --no-passive**
Exit immediately if the lock cannot be acquired, instead of waiting.

**-f, --foreground**
Run the daemon in the foreground, preventing it from forking into the background.

**-v, --verbose**
Enable verbose output to provide more detailed logging information.

**-t, --trace**
Enable trace output from kinit, useful for debugging Kerberos authentication issues.

**-l, --no-lock**
Allow multiple instances of the daemon to run simultaneously by ignoring the singleton lock.

**-b, --no-block**
Proceed without waiting if the initial ticket acquisition fails.

**-k, --keytab=\<existing path\>**
Specify a custom path for the keytab file. If not provided, the keytab file will be auto-detected based on the following search order:  
	1. `/etc/$USER.keytab`  
	2. `$HOME/.krenewd/krb5.keytab`  
	3. `$HOME/$USER.keytab`  
	4. `$HOME/krb5.keytab`  
	5. `$HOME/.krb5.keytab`  
	6. `/etc/krb5.keytab`  

# ENVIRONMENT VARIABLES
The following environment variables can be set to provide default values for command-line options:

- **XDG_SESSION_ID**: Specifies the default session ID to monitor if `--session-id` is not provided.
- **KRENEWD_INTERVAL**: Sets the default interval between ticket renewals in seconds.
- **KRENEWD_DESTROY**: If set, enables ticket destruction on exit as per the `--destroy` option.
- **KRENEWD_NOPASSIVE**: If set, enables the `--no-passive` behavior to exit immediately if the lock cannot be acquired.
- **KRENEWD_FOREGROUND**: If set, prevents the daemon from forking into the background, equivalent to the `--foreground` option.
- **KRENEWD_VERBOSE**: If set, enables verbose logging output.
- **KRENEWD_TRACE**: If set, enables trace output for debugging Kerberos issues as per the `--trace` option.
- **KRENEWD_NOLOCK**: If set, allows multiple instances of the daemon to run simultaneously, mirroring the `--no-lock` option.
- **KRENEWD_NOBLOCK**: If set, enables the `--no-block` behavior to proceed without waiting if initial ticket acquisition fails.
- **KRENEWD_KEYTAB**: Sets a default keytab file path for authentication if `--keytab` is not specified.

# EXAMPLES
1. To run the daemon from your profile or bashrc, include the `--no-block` option:  
   ```bash
   krenewd --no-block
   ```  

2. To enable the service for a specific daemon user:  
   ```bash
   systemctl enable --now krenewd@USERNAME.service
   ```  
   Replace `USERNAME` with the name of the daemon user.

# AUTHOR
Written by Simon Brennecke.

# COPYRIGHT
Copyright (C) 2024 Simon Brennecke, licensed under GNU GPL version 3 or later.

# SEE ALSO
*kerberos*(7), *kinit*(1), *klist*(1), *kdestroy*(1)

# NOTES
This manual page was written for `krenewd` version `30.xxxxxxx`. The behavior may differ in other versions.
