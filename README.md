# krenewd

krenewd is a daemon designed to automatically refresh Kerberos tickets. This tool is particularly useful in environments where long-running sessions require continuous ticket renewals to maintain authentication for various services.

## Features

- **Session Monitoring**: Specify the login session ID to monitor, defaulting to the current session.
- **Process Monitoring**: Monitor a specific process, or the parent process by default, to manage ticket renewals based on process activity.
- **Flexible Time Intervals**: Set custom time intervals for ticket renewals.
- **Secure Ticket Handling**: Option to destroy tickets on exit, ensuring security when the daemon stops.
- **Foreground Operation**: Run directly in the foreground for easier debugging.
- **Verbose and Trace Outputs**: Get detailed logs for normal operations or trace outputs from `kinit` for in-depth debugging.
- **Concurrency Control**: Options to handle singleton locks and allow or prevent multiple instances.

## Usage

```bash
./krenewd [OPTIONS]
```

### Options

- `-h, --help`: Show command-line help.
- `-s, --session-id=<string>`: Specify the login session ID. Defaults to `$XDG_SESSION_ID`.
- `-m, --master`: Specify the PID to monitor. Set to `0` to disable.
- `-i, --interval`: Time interval in seconds between ticket renewals. Defaults to `200`.
- `-d, --destroy`: Destroy the ticket on exit if the lock was acquired.
- `-p, --no-passive`: Exit if the lock cannot be acquired immediately.
- `-f, --foreground`: Run in the foreground.
- `-v, --verbose`: Enable verbose output.
- `-t, --trace`: Enable trace debugging output.
- `-l, --no-lock`: Allow multiple instances to run simultaneously.
- `-b, --no-block`: Proceed even if initial ticket acquisition fails.
- `-k, --keytab`: Specify a keytab file. Auto-detected if not specified.

## Systemd Service

`krenewd` includes a systemd service template, `krenewd@.service`, allowing system administrators to easily manage instances for different daemon users. This service can be instantiated per user with a simple systemd command.

### Managing Service Instances

To start a service instance for a specific user, use:

```bash
systemctl start krenewd@username.service
```

To enable the service to start on boot:

```bash
systemctl enable krenewd@username.service
```

Replace `username` with the actual username of the daemon or service account you wish to manage.

## Installation

To install `krenewd`, use the provided package for your distribution or compile from source using the included Makefile.

## License

krenewd is licensed under the GPL. For more details, see the `LICENSE.md` file in the source distribution.
