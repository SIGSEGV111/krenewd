# krenewd Kubernetes sidecar image

This directory contains the complete image build and packaging flow for the
`krenewd` Kubernetes sidecar. It is intentionally independent from the root
Makefile, which builds the native `krenewd` binary and RPM.

`amp-bash-commons` must be installed at `/opt/amp-bash-commons`; the checked-in
`build_image.sh` symlink points to `/opt/amp-bash-commons/build_image.sh`.

The image installs `krenewd` from the private RPM repository. The Brennecke IT
root CA is copied into the openSUSE trust store before the HTTPS repository is
registered.

## Targets

```bash
make image
make oci
make rpm
make deploy RPMDIR=/mnt/data/rpm
make clean
```

`image` builds `krenewd-sidecar:local` with `build_image.sh` and tags it as
`docker.io/library/krenewd-sidecar:local`.

`oci` writes `krenewd-sidecar.oci` as a portable OCI image archive.

`rpm` creates `krenewd-sidecar-image.<arch>.rpm`. The RPM contains a
Docker-format image archive so it can be imported into Docker, Podman and
K3s/containerd. During RPM installation every locally available runtime is
updated. If K3s is installed but its containerd is unavailable, the archive is
queued below `/var/lib/rancher/k3s/agent/images`.

`deploy` signs and copies the image RPM with `deploy-rpm.sh`; set `RPMDIR` to the
destination repository directory.

For an explicit target architecture:

```bash
make rpm RPM_ARCH=aarch64
make rpm RPM_ARCH=x86_64
```

The corresponding container architectures are mapped to `arm64` and `amd64`
for `build_image.sh`.

The entrypoint starts as root only to prepare the host credential-cache
directory and a private in-memory copy of the keytab. It then switches to the
workload UID and GID with `setpriv` and starts `krenewd` without privilege
escalation.
