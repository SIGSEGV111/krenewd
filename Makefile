.PHONY: all clean install rpm doc deploy rpm-install

ARCH ?= $(shell rpm --eval '%{_target_cpu}')
CXXFLAGS ?=
LDFLAGS ?=

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

all: krenewd

doc: krenewd.1

rpm: $(ARCH_RPM_NAME)

rpm-install: rpm
	zypper in "./$(ARCH_RPM_NAME)"

clean:
	rm -vf -- krenewd krenewd.1 *.rpm

krenewd: krenewd.cpp Makefile
	clang++ $(CXXFLAGS) $(LDFLAGS) -fuse-ld=lld -Wall -Wextra -std=gnu++20 -flto=auto -Os -lsystemd -lel1 -lkrb5 "-DVERSION=\"$(VERSION)\"" -o krenewd krenewd.cpp
	./krenewd --version

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
	easy-rpm.sh --name krenewd --outdir . --plain --arch "$(ARCH)" -- $^
