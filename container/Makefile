.PHONY: clean image oci rpm deploy

KEYID ?= BE5096C665CA4595AF11DAB010CD9FF74E4565ED

IMAGE_NAME := krenewd-sidecar
IMAGE_TAG ?= local
IMAGE_REF := docker.io/library/$(IMAGE_NAME):$(IMAGE_TAG)

ARCH ?= $(shell if command -v rpm >/dev/null 2>&1; then rpm --eval '%{_target_cpu}'; else uname -m; fi)
OCI_ARCHIVE := $(IMAGE_NAME).$(ARCH).oci
RUNTIME_ARCHIVE := $(IMAGE_NAME).$(ARCH).image.tar
IMAGE_REF_FILE := $(IMAGE_NAME).$(ARCH).image-ref

RPM_NAME := krenewd-sidecar-image
RPM_FILE := $(RPM_NAME).$(ARCH).rpm

image:
	./build_image.sh --arch "$(ARCH)" --force-image-tag "$(IMAGE_TAG)"
	podman tag "$(IMAGE_NAME):$(IMAGE_TAG)" "$(IMAGE_REF)"

oci: $(OCI_ARCHIVE)

$(OCI_ARCHIVE): image
	rm -f -- "$@"
	podman save \
		--format oci-archive \
		--output "$@" \
		"$(IMAGE_REF)"

$(RUNTIME_ARCHIVE): image
	rm -f -- "$@"
	podman save \
		--format docker-archive \
		--output "$@" \
		"$(IMAGE_REF)"

$(IMAGE_REF_FILE): Makefile
	printf '%s\n' "$(IMAGE_REF)" > "$@"

rpm: $(RPM_FILE)

$(RPM_FILE): $(RUNTIME_ARCHIVE) $(IMAGE_REF_FILE) install-image.sh $(RPM_NAME).spec Makefile
	easy-rpm.sh \
		--name "$(RPM_NAME)" \
		--outdir . \
		--plain \
		--arch "$(ARCH)" \
		-- \
		$(RUNTIME_ARCHIVE) \
		$(IMAGE_REF_FILE) \
		install-image.sh \
		$(RPM_NAME).spec \
		Makefile

deploy: $(RPM_FILE)
	@test -n "$(RPMDIR)" || { echo "RPMDIR is required" >&2; exit 2; }
	ensure-git-clean.sh
	deploy-rpm.sh --infile="$(RPM_FILE)" --outdir="$(RPMDIR)" --keyid="$(KEYID)"

clean:
	rm -vf -- \
		$(OCI_ARCHIVE) \
		$(RUNTIME_ARCHIVE) \
		$(IMAGE_REF_FILE) \
		*.rpm
