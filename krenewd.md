# NAME
krenewd - Kerberos ticket refresh daemon

# SYNOPSIS
krenewd [OPTION]...

# DESCRIPTION
**krenewd** is a daemon designed to automatically renew Kerberos tickets. It monitors specified session or process IDs and renews Kerberos tickets at defined intervals, utilizing a specified keytab file if provided. If no keytab file is specified, it follows an auto-detection sequence to find an existing keytab.

# OPTIONS
-h, --help
Display the help text and exit.

-V, --version
Show version and copyright information, then exit.

-s, --session-id=\<string\>
Specify the login session ID to monitor, defaulting to the current session as determined by XDG_SESSION_ID.

-m, --master=\<pid\>
Set the process ID to monitor. Specify '0' to disable monitoring. If neither process nor session IDs are provided, the parent process is monitored by default. Overrides `--session-id`.

-i, --interval=\<seconds\>
Define the time interval between ticket renewals, in seconds. Default is 200 seconds. Controlled by the KRENEWD_INTERVAL environment variable.

-d, --destroy
Destroy the ticket on exit but only if the lock was acquired during the session or if 'no-lock' was specified.

-p, --no-passive
Exit immediately if the lock cannot be acquired, instead of waiting.

-f, --foreground
Run the daemon in the foreground, preventing it from forking into the background.

-v, --verbose
Enable verbose output to provide more detailed logging information.

-t, --trace
Enable trace output from kinit, useful for debugging Kerberos authentication issues.

-l, --no-lock
Allow multiple instances of the daemon to run simultaneously by ignoring the singleton lock.

-b, --no-block
Proceed without waiting if the initial ticket acquisition fails.

-k, --keytab=\<existing path\>
Specify a custom path for the keytab file. If not provided, the keytab file will be auto-detected based on the following search order:
1. `/etc/$USER.keytab`
2. `$HOME/$USER.keytab`
3. `$HOME/krb5.keytab`
4. `/etc/krb5.keytab`

# EXAMPLES
1. To run the daemon from your profile or bashrc you should make sure to include the `--no-block` option:
   ```
   krenewd --no-block
   ```

2. To enable the service for a specific daemon user use this command:
   ```
   systemctl enable --now krenewd@USERNAME.service
   ```
   Where USERNAME has to be replaced by the name of the daemon user.

# AUTHOR
Written by Simon Brennecke.

# COPYRIGHT
Copyright (C) 2024 Simon Brennecke, licensed under GNU GPL version 3 or later.

# SEE ALSO
*kerberos*(1), *kinit*(1), *klist*(1), *kdestroy*(1)

# NOTES
This manual page was written for the krenewd version 20240814011414. The behavior may differ in other versions.
