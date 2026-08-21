.DEFAULT_GOAL := all

STD_PROFILE := cxx-apps
STD_ENABLE_X86_64_V2 := 1
USE_EL1 := 1
CI_ENABLE := 1

CXX := clang++
CXX_STANDARD := gnu++20
RELEASE_CXXFLAGS := -Os -g -DNDEBUG -flto=auto
DEBUG_CXXFLAGS := -O0 -g3 -fno-omit-frame-pointer
PACKAGE_NAMES :=

BINDIR ?= /usr/bin
MANDIR ?= /usr/share/man
UNITDIR ?= /usr/lib/systemd/system
LIBEXECDIR ?= /usr/libexec/krenewd
NFSCONFDIR ?= /etc/nfs.conf.d

PROGRAM_IDS := MAIN
PROGRAM_MAIN_NAME := krenewd
PROGRAM_MAIN_SOURCES := krenewd.cpp
PROGRAM_MAIN_LDLIBS := -lsystemd -lkrb5
PROGRAM_MAIN_VERIFY_ARGS := --version

RPM_PACKAGE_IDS := MAIN
RPM_MAIN_NAME := krenewd
RPM_MAIN_SPEC := krenewd.spec
RPM_MAIN_DEFINES = el1_version=$(EL1_VERSION)
RPM_MAIN_SOURCE_FILES := \
	krenewd.cpp krenewd.pam krenewd@.service \
	krenewd-migrate-service-instances.sh krenewd-nfs.conf \
	krenewd.spec README.md

include submodules/std-make-lib/Makefile.common

ARCH_RPM_NAME := $(RPM_MAIN_ARCH_FILE)
SRC_RPM_NAME := $(RPM_MAIN_SRC_FILE)

.PHONY: doc install rpm-install clean-project

doc: krenewd.1

krenewd.1: README.md $(STD_PROJECT_MAKEFILES)
	go-md2man < README.md > krenewd.1

install: release krenewd.1 krenewd.pam krenewd@.service krenewd-migrate-service-instances.sh krenewd-nfs.conf
	mkdir -p "$(BINDIR)" "$(MANDIR)/man1" "$(UNITDIR)" "$(LIBEXECDIR)" "$(NFSCONFDIR)"
	install -m 755 "$(PROGRAM_MAIN_RELEASE_FILE)" "$(BINDIR)/krenewd"
	install -m 755 krenewd.pam "$(BINDIR)/"
	install -m 755 krenewd-migrate-service-instances.sh "$(LIBEXECDIR)/"
	install -m 644 krenewd@.service "$(UNITDIR)/"
	install -m 644 krenewd-nfs.conf "$(NFSCONFDIR)/krenewd.conf"
	install -m 644 krenewd.1 "$(MANDIR)/man1/"

rpm-install: rpm
	zypper in "./$(ARCH_RPM_NAME)"

clean: clean-project
clean-project:
	rm -f -- krenewd.1 *.rpm
