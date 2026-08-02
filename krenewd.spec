%define el1_min_version 124

Name:           krenewd
Summary:        Kerberos Ticket Refresh Daemon
Group:          System Environment/Daemons
Distribution:   openSUSE
License:        GPLv3
URL:            https://www.brennecke-it.net

BuildRequires:  clang
BuildRequires:  el1-devel >= %{el1_min_version}
BuildRequires:  go-md2man
BuildRequires:  lld
BuildRequires:  pkgconfig(krb5)
BuildRequires:  pkgconfig(libsystemd)
Requires:       el1 >= %{el1_min_version}
Requires:       krb5-client
Requires:       /usr/sbin/runuser
Requires(post): sed
Requires(post): systemd
Requires(postun): systemd

%description
krenewd is a daemon designed to automate the renewal of Kerberos tickets, ensuring continuous authentication without manual intervention. It is particularly useful in environments where long-running processes need to maintain authenticated sessions over extended periods. krenewd includes a systemd service template, making it easy for system administrators to instantiate multiple daemon processes for various daemon users.

%prep
%setup -q -n krenewd

%build
make %{?_smp_mflags} VERSION="Version %{version}"

%install
make install BINDIR=%{buildroot}%{_bindir} UNITDIR="%{buildroot}%{_unitdir}" MANDIR="%{buildroot}%{_mandir}" LIBEXECDIR="%{buildroot}%{_libexecdir}/krenewd" NFSCONFDIR="%{buildroot}/etc/nfs.conf.d"

%post
if command -v systemctl >/dev/null 2>&1; then
	%{_libexecdir}/krenewd/krenewd-migrate-service-instances.sh || :
	systemctl try-restart rpc-gssd.service || :
fi

# Migrate references left by installations predating the RPM package.
for pam_file in /etc/pam.d/common-*; do
	[ -f "$pam_file" ] || continue
	sed -i 's|/usr/local/bin/krenewd.pam|/usr/bin/krenewd.pam|g' "$pam_file"
done
if [ -f /etc/profile.d/krenewd.sh ]; then
	sed -i 's|/usr/local/bin/krenewd|/usr/bin/krenewd|g' /etc/profile.d/krenewd.sh
fi
rm -vf /usr/local/bin/krenewd /usr/local/bin/krenewd.pam

%postun
if [ "$1" -eq 0 ] && command -v systemctl >/dev/null 2>&1; then
	systemctl daemon-reload || :
	systemctl try-restart rpc-gssd.service || :
fi

%files
%{_bindir}/krenewd
%{_bindir}/krenewd.pam
%dir %{_libexecdir}/krenewd
%{_libexecdir}/krenewd/krenewd-migrate-service-instances.sh
%{_unitdir}/krenewd@.service
%dir /etc/nfs.conf.d
%config(noreplace) /etc/nfs.conf.d/krenewd.conf
%{_mandir}/man1/krenewd.1.gz

%changelog
