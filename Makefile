.PHONY: all clean install rpm doc deploy rpm-install FORCE

ARCH ?= $(shell rpm --eval '%{_target_cpu}')
CXXFLAGS ?=
LDFLAGS ?=

EL1_INCLUDE_DIR ?=
EL1_LIB_DIR ?=

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
EL1_CONFIG_STAMP := gen/.el1-config

all: krenewd

doc: krenewd.1

rpm: $(ARCH_RPM_NAME)

rpm-install: rpm
	zypper in "./$(ARCH_RPM_NAME)"

clean:
	rm -vf -- krenewd krenewd.1 *.rpm
	rm -rf -- gen

FORCE:

$(EL1_CONFIG_STAMP): FORCE
	@mkdir -p "$(@D)"
	@printf '%s\n' 'EL1_INCLUDE_DIR=$(EL1_INCLUDE_DIR)' 'EL1_LIB_DIR=$(EL1_LIB_DIR)' 'EL1_VERSION=$(EL1_VERSION)' > "$@.tmp"
	@if test -f "$@" && cmp -s "$@.tmp" "$@"; then rm -f "$@.tmp"; else mv -f "$@.tmp" "$@"; fi

krenewd: krenewd.cpp Makefile $(EL1_CONFIG_STAMP)
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
