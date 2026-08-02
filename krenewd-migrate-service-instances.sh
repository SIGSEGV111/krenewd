#!/bin/bash
set -u

SYSTEMCTL=${SYSTEMCTL:-systemctl}
GETENT=${GETENT:-getent}
SYSTEMD_ESCAPE=${SYSTEMD_ESCAPE:-systemd-escape}
SYSTEMD_CONFIG_DIRS=${SYSTEMD_CONFIG_DIRS:-/etc/systemd/system /run/systemd/system}

logMessage()
{
	printf 'krenewd: %s\n' "$*" >&2
}

moveUnitConfiguration()
{
	old_unit=$1
	new_unit=$2

	for config_dir in $SYSTEMD_CONFIG_DIRS; do
		old_path="$config_dir/$old_unit"
		new_path="$config_dir/$new_unit"
		old_dropin="$old_path.d"
		new_dropin="$new_path.d"

		if [ -e "$old_path" ] || [ -L "$old_path" ]; then
			if [ -e "$new_path" ] || [ -L "$new_path" ]; then
				logMessage "not moving $old_path because $new_path already exists"
			else
				mv -- "$old_path" "$new_path"
			fi
		fi

		if [ -d "$old_dropin" ]; then
			if [ -e "$new_dropin" ]; then
				logMessage "not moving $old_dropin because $new_dropin already exists"
			else
				mv -- "$old_dropin" "$new_dropin"
			fi
		fi
	done
}

if ! command -v "$SYSTEMCTL" >/dev/null 2>&1; then
	exit 0
fi

units_file=$(mktemp)
state_file=$(mktemp)
trap 'rm -f "$units_file" "$state_file"' EXIT HUP INT TERM

{
	"$SYSTEMCTL" list-unit-files \
		--type=service \
		--no-legend \
		--no-pager \
		'krenewd@*.service' 2>/dev/null | awk '{ print $1 }'
	"$SYSTEMCTL" list-units \
		--type=service \
		--all \
		--full \
		--plain \
		--no-legend \
		--no-pager \
		'krenewd@*.service' 2>/dev/null | awk '{ print $1 }'
} | sort -u > "$units_file"

while IFS= read -r old_unit; do
	case "$old_unit" in
		krenewd@*.service)
			;;
		*)
			continue
			;;
	esac

	encoded_instance=${old_unit#krenewd@}
	encoded_instance=${encoded_instance%.service}
	[ -n "$encoded_instance" ] || continue

	instance=$("$SYSTEMD_ESCAPE" --unescape "$encoded_instance" 2>/dev/null) || {
		logMessage "cannot decode service instance $old_unit"
		continue
	}

	case "$instance" in
		*[!0-9]*)
			action=migrate
			passwd_entry=$("$GETENT" passwd "$instance" 2>/dev/null | head -n 1)
			if [ -z "$passwd_entry" ]; then
				logMessage "cannot migrate $old_unit: user $instance does not exist"
				continue
			fi

			uid=$(printf '%s\n' "$passwd_entry" | cut -d: -f3)
			case "$uid" in
				''|*[!0-9]*)
					logMessage "cannot migrate $old_unit: invalid UID $uid"
					continue
					;;
			esac
			new_unit="krenewd@${uid}.service"
			;;
		*)
			action=refresh
			uid=$instance
			new_unit=$old_unit
			passwd_entry=$("$GETENT" passwd "$uid" 2>/dev/null | head -n 1)
			if [ -z "$passwd_entry" ]; then
				logMessage "cannot refresh $old_unit: UID $uid does not exist"
				continue
			fi
			;;
	esac

	enabled_state=$("$SYSTEMCTL" is-enabled "$old_unit" 2>/dev/null | head -n 1)
	active_state=$("$SYSTEMCTL" is-active "$old_unit" 2>/dev/null | head -n 1)
	enabled_state=${enabled_state:-disabled}
	active_state=${active_state:-inactive}

	printf '%s|%s|%s|%s|%s|%s\n' \
		"$action" \
		"$old_unit" \
		"$new_unit" \
		"$enabled_state" \
		"$active_state" \
		"$instance" >> "$state_file"
done < "$units_file"

while IFS='|' read -r action old_unit new_unit enabled_state active_state instance; do
	[ -n "$old_unit" ] || continue
	[ "$action" = migrate ] || continue
	logMessage "migrating $old_unit to $new_unit"

	case "$active_state" in
		active|activating|reloading)
			"$SYSTEMCTL" stop "$old_unit" || \
				logMessage "failed to stop $old_unit"
			;;
	esac

	case "$enabled_state" in
		enabled-runtime)
			"$SYSTEMCTL" disable --runtime "$old_unit" || \
				logMessage "failed to disable runtime unit $old_unit"
			;;
		enabled)
			"$SYSTEMCTL" disable "$old_unit" || \
				logMessage "failed to disable $old_unit"
			;;
	esac

	moveUnitConfiguration "$old_unit" "$new_unit"
done < "$state_file"

"$SYSTEMCTL" daemon-reload || logMessage 'systemd daemon-reload failed'

while IFS='|' read -r action old_unit new_unit enabled_state active_state instance; do
	[ -n "$old_unit" ] || continue

	if [ "$action" = migrate ]; then
		case "$enabled_state" in
			enabled-runtime)
				"$SYSTEMCTL" enable --runtime "$new_unit" || \
					logMessage "failed to enable runtime unit $new_unit"
				;;
			enabled)
				"$SYSTEMCTL" enable "$new_unit" || \
					logMessage "failed to enable $new_unit"
				;;
		esac

		case "$active_state" in
			active|activating|reloading)
				"$SYSTEMCTL" start "$new_unit" || \
					logMessage "failed to start $new_unit"
				;;
		esac
	else
		case "$active_state" in
			active|activating|reloading)
				logMessage "restarting $old_unit to apply the new runtime directory"
				"$SYSTEMCTL" restart "$old_unit" || \
					logMessage "failed to restart $old_unit"
				;;
		esac
	fi
done < "$state_file"
