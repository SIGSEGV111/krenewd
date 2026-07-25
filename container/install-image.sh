#!/bin/bash
set -u

readonly ARCH="$(uname -m)"
readonly PACKAGE_NAME="krenewd-sidecar-image"
readonly DATA_DIR="/usr/share/${PACKAGE_NAME}"
readonly ARCHIVE="${DATA_DIR}/krenewd-sidecar.${ARCH}.image.tar"
readonly IMAGE_REF_FILE="${DATA_DIR}/krenewd-sidecar.${ARCH}.image-ref"
readonly K3S_IMPORT_DIR="/var/lib/rancher/k3s/agent/images"
readonly K3S_FALLBACK_ARCHIVE="${K3S_IMPORT_DIR}/krenewd-sidecar.image.${ARCH}.tar"

function log()
{
	printf '%s\n' "$*" >&2
}

function get_image_ref()
{
	if [[ ! -r "$IMAGE_REF_FILE" ]]; then
		log "ERROR: image reference file is missing: $IMAGE_REF_FILE"
		return 1
	fi

	local image_ref
	IFS= read -r image_ref < "$IMAGE_REF_FILE"
	if [[ -z "$image_ref" ]]; then
		log "ERROR: image reference file is empty: $IMAGE_REF_FILE"
		return 1
	fi

	printf '%s' "$image_ref"
}

function install_k3s()
{
	local image_ref="$1"

	if ! command -v k3s >/dev/null 2>&1; then
		log "k3s: not installed; skipping"
		return 0
	fi

	log "k3s: importing $image_ref"
	if k3s ctr images import "$ARCHIVE"; then
		rm -f -- "$K3S_FALLBACK_ARCHIVE"
		return 0
	fi

	log "k3s: direct import failed; queueing image in $K3S_IMPORT_DIR"
	install -d -m 0755 "$K3S_IMPORT_DIR"
	install -m 0644 "$ARCHIVE" "$K3S_FALLBACK_ARCHIVE"
}

function install_docker()
{
	local image_ref="$1"

	if ! command -v docker >/dev/null 2>&1; then
		log "docker: not installed; skipping"
		return 0
	fi

	if ! docker info >/dev/null 2>&1; then
		log "docker: installed, but daemon is unavailable; skipping"
		return 0
	fi

	log "docker: importing $image_ref"
	docker image load --input "$ARCHIVE"
	docker image inspect "$image_ref" >/dev/null
}

function install_podman()
{
	local image_ref="$1"

	if ! command -v podman >/dev/null 2>&1; then
		log "podman: not installed; skipping"
		return 0
	fi

	log "podman: importing $image_ref"
	podman image load --input "$ARCHIVE"
	podman image exists "$image_ref"
}

function remove_k3s()
{
	local image_ref="$1"

	rm -f -- "$K3S_FALLBACK_ARCHIVE"
	if command -v k3s >/dev/null 2>&1; then
		k3s ctr images rm "$image_ref" >/dev/null 2>&1 || true
	fi
}

function remove_docker()
{
	local image_ref="$1"

	if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
		docker image rm --force "$image_ref" >/dev/null 2>&1 || true
	fi
}

function remove_podman()
{
	local image_ref="$1"

	if command -v podman >/dev/null 2>&1; then
		podman image rm --force "$image_ref" >/dev/null 2>&1 || true
	fi
}

function install_image()
{
	local image_ref
	image_ref="$(get_image_ref)" || return 1
	[[ -r "$ARCHIVE" ]] || {
		log "ERROR: image archive is missing: $ARCHIVE"
		return 1
	}

	local failed=0
	install_k3s "$image_ref" || failed=1
	install_docker "$image_ref" || failed=1
	install_podman "$image_ref" || failed=1
	return "$failed"
}

function remove_image()
{
	local image_ref
	image_ref="$(get_image_ref)" || return 1

	remove_k3s "$image_ref"
	remove_docker "$image_ref"
	remove_podman "$image_ref"
}

case "${1:-install}" in
	install)
		install_image
		;;
	remove)
		remove_image
		;;
	*)
		echo "Usage: $0 {install|remove}" >&2
		exit 2
		;;
esac
