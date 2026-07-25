Name:           krenewd
Summary:        Kerberos Ticket Refresh Daemon
Group:          System Environment/Daemons
Distribution:   openSUSE
License:        GPLv3
URL:            https://www.brennecke-it.net

BuildRequires:  clang
BuildRequires:  el1 >= 109
BuildRequires:  go-md2man
BuildRequires:  lld
BuildRequires:  pkgconfig(krb5)
BuildRequires:  pkgconfig(libsystemd)
Requires:       el1 >= 109
Requires:       krb5-client
Requires:       /usr/sbin/runuser
Requires(post): sed

%description
krenewd is a versatile daemon designed to automate the renewal of Kerberos tickets, ensuring continuous authentication without manual intervention. It is particularly useful in environments where long-running processes need to maintain authenticated sessions over extended periods. krenewd includes a systemd service template, making it easy for system administrators to instantiate multiple daemon processes for various daemon users. This integration promotes easy management and deployment of kerberos across systems, enhancing security without burdening administrative resources.

%prep
%setup -q -n krenewd

%build
make %{?_smp_mflags} VERSION="Version %{version}"

%install
make install BINDIR=%{buildroot}%{_bindir} UNITDIR="%{buildroot}%{_unitdir}" MANDIR="%{buildroot}%{_mandir}"

%post
if command -v systemctl >/dev/null 2>&1; then
	systemctl daemon-reload || :
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
fi

%files
%{_bindir}/krenewd
%{_bindir}/krenewd.pam
%{_unitdir}/krenewd@.service
%{_mandir}/man1/krenewd.1.gz

%changelog
