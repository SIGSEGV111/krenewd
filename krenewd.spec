Name:           krenewd
Summary:        Kerberos Ticket Refresh Daemon
Group:          System Environment/Daemons
Distribution:   openSUSE
License:        GPLv3
URL:            https://www.brennecke-it.net

BuildRequires:  clang, systemd-devel
Requires:       krb5-client, systemd

%description
krenewd is a versatile daemon designed to automate the renewal of Kerberos tickets, ensuring continuous authentication without manual intervention. It is particularly useful in environments where long-running processes need to maintain authenticated sessions over extended periods. krenewd includes a systemd service template, making it easy for system administrators to instantiate multiple daemon processes for various daemon users. This integration promotes easy management and deployment of kerberos across systems, enhancing security without burdening administrative resources.

%prep
%setup -q -n krenewd

%build
make %{?_smp_mflags} VERSION="Version %{version}"

%install
make install DESTDIR="%{buildroot}" UNITDIR="%{buildroot}%{_unitdir}"

%post
systemctl daemon-reload

%postun
if [ $1 -eq 0 ]; then
    systemctl daemon-reload
fi

%files
%{_bindir}/krenewd
%{_unitdir}/krenewd@.service

%changelog
