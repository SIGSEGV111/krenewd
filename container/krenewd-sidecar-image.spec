Name:           krenewd-sidecar-image
Summary:        Container image for the krenewd Kubernetes sidecar
Group:          System/Management
Distribution:   openSUSE
License:        GPLv3
URL:            https://www.brennecke-it.net

%description
Prebuilt container image for the krenewd Kubernetes sidecar. The package
imports the image into every locally available supported runtime: K3s/containerd,
Docker, and Podman. The packaged image archive is retained so the import can be
repeated later.

%prep
%setup -q -n krenewd-sidecar-image

%install
install -d \
	%{buildroot}%{_datadir}/krenewd-sidecar-image \
	%{buildroot}%{_libexecdir}/krenewd-sidecar-image
install -m 0644 \
	krenewd-sidecar.image.tar \
	%{buildroot}%{_datadir}/krenewd-sidecar-image/
install -m 0644 \
	krenewd-sidecar.image-ref \
	%{buildroot}%{_datadir}/krenewd-sidecar-image/
install -m 0755 \
	install-image.sh \
	%{buildroot}%{_libexecdir}/krenewd-sidecar-image/install-image

%post
if ! %{_libexecdir}/krenewd-sidecar-image/install-image install; then
	echo "WARNING: one or more container-runtime image imports failed" >&2
	echo "Retry with: %{_libexecdir}/krenewd-sidecar-image/install-image install" >&2
fi

%preun
if [ "$1" -eq 0 ]; then
	%{_libexecdir}/krenewd-sidecar-image/install-image remove || :
fi

%files
%dir %{_datadir}/krenewd-sidecar-image
%{_datadir}/krenewd-sidecar-image/krenewd-sidecar.image.tar
%{_datadir}/krenewd-sidecar-image/krenewd-sidecar.image-ref
%dir %{_libexecdir}/krenewd-sidecar-image
%{_libexecdir}/krenewd-sidecar-image/install-image

%changelog
