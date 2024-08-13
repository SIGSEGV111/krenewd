.PHONY: all clean install

ifeq ($(VERSION),)
    VERSION = *DEVELOPMENT SNAPSHOT*
endif

all: krenewd

clean:
	rm -f -- krenewd

krenewd: krenewd.cpp Makefile
	clang++ -Wall -Wextra -std=gnu++20 -flto -Os -lsystemd "-DVERSION=\"$(VERSION)\"" -o $@ krenewd.cpp
	./krenewd --version

install: krenewd
	mkdir -p "$(DESTDIR)/usr/bin"
	install krenewd "$(DESTDIR)/usr/bin/"
	install -D -m 644 krenewd@.service "$(UNITDIR)/krenewd@.service"

rpm: krenewd.cpp krenewd@.service Makefile krenewd.spec
	easy-rpm.sh --name krenewd --outdir . --sign --keyid BE5096C665CA4595AF11DAB010CD9FF74E4565ED --inspect --debug -- $^
