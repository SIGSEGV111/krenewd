.PHONY: all clean install

ifeq ($(VERSION),)
    VERSION = *DEVELOPMENT SNAPSHOT*
endif

BINDIR ?= /usr/bin
MANDIR ?= /usr/share/man
UNITDIR ?= /usr/lib/systemd/system

all: krenewd

clean:
	rm -f -- krenewd

krenewd: krenewd.cpp Makefile
	pandoc -s -f markdown -t man krenewd.md -o krenewd.1
	clang++ -Wall -Wextra -std=gnu++20 -flto -Os -lsystemd "-DVERSION=\"$(VERSION)\"" -o $@ krenewd.cpp
	./krenewd --version

install: krenewd
	mkdir -p "$(BINDIR)" "$(MANDIR)/man1" "$(UNITDIR)"
	install krenewd "$(BINDIR)/"
	install -m 644 krenewd@.service "$(UNITDIR)/krenewd@.service"
	install -m 644 krenewd.1 "$(MANDIR)/man1/krenewd.1"

rpm: krenewd.cpp krenewd@.service Makefile krenewd.spec krenewd.md
	@if [ -z "$(RPMDIR)" ]; then \
		easy-rpm.sh --name krenewd --outdir . --plain --sign --keyid BE5096C665CA4595AF11DAB010CD9FF74E4565ED --inspect --debug -- $^; \
	else \
		easy-rpm.sh --name krenewd --outdir "$(RPMDIR)" --sign --keyid BE5096C665CA4595AF11DAB010CD9FF74E4565ED --inspect --debug -- $^; \
	fi
