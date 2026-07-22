# krenewd Kubernetes sidecar image

Build this image natively for each Kubernetes node architecture. Put the matching
`el1` and `krenewd` RPMs in `container/rpms/`, then run:

```bash
buildah bud -t docker.io/library/krenewd-sidecar:local container/
buildah push docker.io/library/krenewd-sidecar:local oci-archive:/tmp/krenewd-sidecar.oci:docker.io/library/krenewd-sidecar:local
sudo k3s ctr images import /tmp/krenewd-sidecar.oci
```

On a K3s agent use `sudo k3s ctr images import` as well; K3s' CLI selects its
containerd endpoint. Import the architecture-matching image on every node that
may run Kerberos-enabled Pods.

The entrypoint starts as root only to prepare the host credential-cache directory
and a private in-memory copy of the keytab. It then switches to the workload UID
and GID with `setpriv` and starts `krenewd` without privilege escalation.
