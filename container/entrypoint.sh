#!/usr/bin/bash
set -euo pipefail

: "${KERBEROS_USERNAME:?KERBEROS_USERNAME is required}"
: "${KERBEROS_UID:?KERBEROS_UID is required}"
: "${KERBEROS_GID:?KERBEROS_GID is required}"
: "${KRB5CCNAME:?KRB5CCNAME is required}"
: "${KERBEROS_KEYTAB_SOURCE:?KERBEROS_KEYTAB_SOURCE is required}"
: "${KRENEWD_KEYTAB:?KRENEWD_KEYTAB is required}"
: "${KRENEWD_PRINCIPAL:?KRENEWD_PRINCIPAL is required}"
: "${KRENEWD_LOCKDIR:?KRENEWD_LOCKDIR is required}"

cache_dir="${KRB5CCNAME#DIR:}"
if [[ "${cache_dir}" == "${KRB5CCNAME}" || -z "${cache_dir}" ]]; then
	echo "KRB5CCNAME must use a DIR: cache" >&2
	exit 2
fi

install -d -m 0700 -o "${KERBEROS_UID}" -g "${KERBEROS_GID}" "${cache_dir}"
install -d -m 0700 -o "${KERBEROS_UID}" -g "${KERBEROS_GID}" "$(dirname -- "${KRENEWD_KEYTAB}")"
install -m 0400 -o "${KERBEROS_UID}" -g "${KERBEROS_GID}" "${KERBEROS_KEYTAB_SOURCE}" "${KRENEWD_KEYTAB}"

# krenewd resolves its own UID through getpwuid(). The application container does
# not have to contain the LDAP account, so provide the already-resolved identity
# locally in this sidecar before dropping privileges.
if ! getent passwd "${KERBEROS_UID}" >/dev/null; then
	printf '%s:x:%s:%s:Kerberos workload:/nonexistent:/sbin/nologin\n' \
		"${KERBEROS_USERNAME}" "${KERBEROS_UID}" "${KERBEROS_GID}" >> /etc/passwd
fi

if ! getent group "${KERBEROS_GID}" >/dev/null; then
	printf '%s:x:%s:\n' "${KERBEROS_USERNAME}" "${KERBEROS_GID}" >> /etc/group
fi

exec setpriv \
	--inh-caps=-all \
	--reuid "${KERBEROS_UID}" \
	--regid "${KERBEROS_GID}" \
	--clear-groups \
	--no-new-privs \
	/usr/bin/krenewd \
		--master=0 \
		--foreground
