.PHONY: all clean install rpm doc deploy rpm-install prepare-el1-dirs ci FORCE

ARCH ?= $(shell rpm --eval '%{_target_cpu}')
CXXFLAGS ?=
LDFLAGS ?=

EL1_INCLUDE_DIR ?=
EL1_LIB_DIR ?=
EL1_RPM_DIR ?=
EL1_PREPARE_DIR ?= gen/el1-rpm
EL1_PREPARE_ROOT := $(abspath $(EL1_PREPARE_DIR))
EL1_PREPARED_INCLUDE_DIR := $(EL1_PREPARE_ROOT)$(shell rpm --eval '%{_includedir}' 2>/dev/null)
EL1_PREPARED_LIB_DIR := $(EL1_PREPARE_ROOT)$(shell rpm --eval '%{_libdir}' 2>/dev/null)
EL1_RPM_BOOTSTRAP := $(and $(strip $(EL1_RPM_DIR)),$(filter ci prepare-el1-dirs,$(MAKECMDGOALS)))

ifeq ($(EL1_RPM_BOOTSTRAP),)
ifneq ($(strip $(EL1_INCLUDE_DIR)$(EL1_LIB_DIR)),)
ifeq ($(strip $(EL1_INCLUDE_DIR)),)
$(error EL1_INCLUDE_DIR must be set together with EL1_LIB_DIR)
endif
ifeq ($(strip $(EL1_LIB_DIR)),)
$(error EL1_LIB_DIR must be set together with EL1_INCLUDE_DIR)
endif
ifeq ($(wildcard $(EL1_INCLUDE_DIR)/el1/el1.hpp),)
$(error EL1_INCLUDE_DIR='$(EL1_INCLUDE_DIR)' does not contain el1/el1.hpp)
endif
ifeq ($(wildcard $(EL1_LIB_DIR)/libel1.so),)
$(error EL1_LIB_DIR='$(EL1_LIB_DIR)' does not contain libel1.so)
endif
endif

EL1_READELF := $(shell command -v readelf 2>/dev/null || command -v llvm-readelf 2>/dev/null)
ifneq ($(strip $(EL1_LIB_DIR)),)
EL1_DETECTED_VERSION := $(strip $(shell \
	if [ -n "$(EL1_READELF)" ]; then \
		"$(EL1_READELF)" -d "$(EL1_LIB_DIR)/libel1.so" 2>/dev/null | \
			sed -n 's/.*SONAME.*\[libel1\.so\.\([^]]*\)\].*/\1/p' | head -n1; \
	elif [ -L "$(EL1_LIB_DIR)/libel1.so" ]; then \
		basename "$$(readlink "$(EL1_LIB_DIR)/libel1.so")" | sed 's/^libel1\.so\.//'; \
	fi))
else
EL1_DETECTED_VERSION := $(strip $(shell pkg-config --modversion el1 2>/dev/null))
endif
ifeq ($(strip $(EL1_DETECTED_VERSION)),)
$(error unable to determine el1 version; build el1 first or install an el1-devel package providing el1.pc)
endif
override EL1_VERSION := $(EL1_DETECTED_VERSION)

ifneq ($(strip $(EL1_LIB_DIR)),)
EL1_LIBRARY_LINK := $(EL1_LIB_DIR)/libel1.so
else
EL1_SYSTEM_LIB_DIR := $(strip $(shell pkg-config --variable=libdir el1 2>/dev/null))
EL1_LIBRARY_LINK := $(EL1_SYSTEM_LIB_DIR)/libel1.so
endif
EL1_LIBRARY_FILE := $(realpath $(EL1_LIBRARY_LINK))
ifeq ($(strip $(EL1_LIBRARY_FILE)),)
$(error unable to resolve selected el1 library '$(EL1_LIBRARY_LINK)')
endif
endif

EL1_CPPFLAGS := $(if $(EL1_INCLUDE_DIR),-I$(EL1_INCLUDE_DIR))
EL1_LDFLAGS := $(if $(EL1_LIB_DIR),-L$(EL1_LIB_DIR))
ifneq ($(EL1_LIB_DIR),)
EL1_RUN_ENV := LD_LIBRARY_PATH="$(EL1_LIB_DIR)$${LD_LIBRARY_PATH:+:$${LD_LIBRARY_PATH}}"
else
EL1_RUN_ENV :=
endif

export EL1_INCLUDE_DIR EL1_LIB_DIR EL1_VERSION

ifeq ($(ARCH),x86_64)
	CXXFLAGS += -march=x86-64-v2
endif

ifeq ($(VERSION),)
	VERSION = *DEVELOPMENT SNAPSHOT*
endif

BINDIR ?= /usr/bin
MANDIR ?= /usr/share/man
UNITDIR ?= /usr/lib/systemd/system
LIBEXECDIR ?= /usr/libexec/krenewd
NFSCONFDIR ?= /etc/nfs.conf.d
KEYID ?= BE5096C665CA4595AF11DAB010CD9FF74E4565ED
ARCH_RPM_NAME := krenewd.$(ARCH).rpm
SRC_RPM_NAME := krenewd.src.rpm
CI_DIR ?= gen/jenkins
CI_RPM_DIR := $(CI_DIR)/rpm
EL1_CONFIG_STAMP := gen/.el1-config
EL1_CONFIG_KEY := $(EL1_INCLUDE_DIR)|$(EL1_LIB_DIR)|$(EL1_VERSION)|$(EL1_LIBRARY_FILE)
EL1_PREVIOUS_CONFIG := $(strip $(shell cat "$(EL1_CONFIG_STAMP)" 2>/dev/null))
ifneq ($(EL1_PREVIOUS_CONFIG),$(EL1_CONFIG_KEY))
EL1_REBUILD_TRIGGER := FORCE
else
EL1_REBUILD_TRIGGER :=
endif

all: krenewd

doc: krenewd.1

rpm: $(ARCH_RPM_NAME)

ci:
	rm -rf -- "$(CI_DIR)"
	mkdir -p -- "$(CI_RPM_DIR)"
ifneq ($(strip $(EL1_RPM_DIR)),)
	$(MAKE) --no-print-directory prepare-el1-dirs
	$(MAKE) --no-print-directory rpm EL1_RPM_DIR= EL1_INCLUDE_DIR="$(EL1_PREPARED_INCLUDE_DIR)" EL1_LIB_DIR="$(EL1_PREPARED_LIB_DIR)"
else
	$(MAKE) --no-print-directory rpm
endif
	cp -f -- "$(ARCH_RPM_NAME)" "$(SRC_RPM_NAME)" "$(CI_RPM_DIR)/"
	@printf 'RPM artifacts: %s\n' "$(abspath $(CI_RPM_DIR))"

rpm-install: rpm
	zypper in "./$(ARCH_RPM_NAME)"

clean:
	rm -vf -- krenewd krenewd.1 *.rpm
	rm -rf -- gen

FORCE:

prepare-el1-dirs:
	@set -eu; \
	if [ -z "$(strip $(EL1_RPM_DIR))" ]; then \
		echo "ERROR: EL1_RPM_DIR must point to the directory containing the el1 RPM artifacts" >&2; \
		exit 1; \
	fi; \
	for tool in rpm rpm2cpio cpio; do \
		command -v "$$tool" >/dev/null 2>&1 || { echo "ERROR: required tool '$$tool' not found" >&2; exit 1; }; \
	done; \
	rpm_dir="$(abspath $(EL1_RPM_DIR))"; \
	runtime_rpm="$$rpm_dir/el1.$(ARCH).rpm"; \
	devel_rpm="$$rpm_dir/el1-devel.$(ARCH).rpm"; \
	for rpm_file in "$$runtime_rpm" "$$devel_rpm"; do \
		test -f "$$rpm_file" || { echo "ERROR: missing el1 RPM '$$rpm_file'" >&2; exit 1; }; \
	done; \
	test "$$(rpm -qp --queryformat '%{NAME}' "$$runtime_rpm")" = "el1" || { echo "ERROR: '$$runtime_rpm' is not the el1 runtime RPM" >&2; exit 1; }; \
	test "$$(rpm -qp --queryformat '%{NAME}' "$$devel_rpm")" = "el1-devel" || { echo "ERROR: '$$devel_rpm' is not the el1-devel RPM" >&2; exit 1; }; \
	runtime_version="$$(rpm -qp --queryformat '%{VERSION}' "$$runtime_rpm")"; \
	devel_version="$$(rpm -qp --queryformat '%{VERSION}' "$$devel_rpm")"; \
	test "$$runtime_version" = "$$devel_version" || { echo "ERROR: el1 RPM version mismatch: runtime=$$runtime_version devel=$$devel_version" >&2; exit 1; }; \
	rm -rf -- "$(EL1_PREPARE_ROOT)"; \
	mkdir -p -- "$(EL1_PREPARE_ROOT)"; \
	(cd "$(EL1_PREPARE_ROOT)" && rpm2cpio "$$runtime_rpm" | cpio -idm --quiet); \
	(cd "$(EL1_PREPARE_ROOT)" && rpm2cpio "$$devel_rpm" | cpio -idm --quiet); \
	test -f "$(EL1_PREPARED_INCLUDE_DIR)/el1/el1.hpp" || { echo "ERROR: prepared el1 headers are incomplete" >&2; exit 1; }; \
	test -e "$(EL1_PREPARED_LIB_DIR)/libel1.so" || { echo "ERROR: prepared el1 library is incomplete" >&2; exit 1; }; \
	printf 'Prepared el1 %s: include=%s lib=%s\n' "$$runtime_version" "$(EL1_PREPARED_INCLUDE_DIR)" "$(EL1_PREPARED_LIB_DIR)"

$(EL1_CONFIG_STAMP): FORCE
	@mkdir -p "$(@D)"
	@printf '%s\n' '$(EL1_CONFIG_KEY)' > "$@.tmp"
	@if test -f "$@" && cmp -s "$@.tmp" "$@"; then rm -f "$@.tmp"; else mv -f "$@.tmp" "$@"; fi

krenewd: krenewd.cpp Makefile $(EL1_CONFIG_STAMP) $(EL1_REBUILD_TRIGGER) $(EL1_LIBRARY_FILE)
	clang++ $(EL1_CPPFLAGS) $(CXXFLAGS) $(EL1_LDFLAGS) $(LDFLAGS) -fuse-ld=lld -Wall -Wextra -std=gnu++20 -flto=auto -Os -lsystemd -lel1 -lkrb5 "-DVERSION=\"$(VERSION)\"" -o krenewd krenewd.cpp
	$(EL1_RUN_ENV) ./krenewd --version

krenewd.1: README.md Makefile
	go-md2man < README.md > krenewd.1

install: krenewd.1 krenewd krenewd.pam krenewd@.service krenewd-migrate-service-instances.sh krenewd-nfs.conf Makefile
	mkdir -p "$(BINDIR)" "$(MANDIR)/man1" "$(UNITDIR)" "$(LIBEXECDIR)" "$(NFSCONFDIR)"
	install -m 755 krenewd "$(BINDIR)/"
	install -m 755 krenewd.pam "$(BINDIR)/"
	install -m 755 krenewd-migrate-service-instances.sh "$(LIBEXECDIR)/"
	install -m 644 krenewd@.service "$(UNITDIR)/"
	install -m 644 krenewd-nfs.conf "$(NFSCONFDIR)/krenewd.conf"
	install -m 644 krenewd.1 "$(MANDIR)/man1/"

deploy: $(ARCH_RPM_NAME)
	ensure-git-clean.sh
	deploy-rpm.sh --infile=krenewd.src.rpm --outdir="$(RPMDIR)" --keyid="$(KEYID)"
	deploy-rpm.sh --infile="$(ARCH_RPM_NAME)" --outdir="$(RPMDIR)" --keyid="$(KEYID)"

$(ARCH_RPM_NAME) krenewd.src.rpm: krenewd.cpp krenewd.pam krenewd@.service krenewd-migrate-service-instances.sh krenewd-nfs.conf Makefile krenewd.spec README.md
	easy-rpm.sh --define "el1_version=$(EL1_VERSION)" --name krenewd --outdir . --plain --arch "$(ARCH)" -- $^
