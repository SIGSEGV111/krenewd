.PHONY: all clean install

all: krenewd

install: krenewd
	sudo install krenewd         /usr/local/bin/
	sudo install krenewd.service /usr/lib/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable krenewd.service
	sudo systemctl restart krenewd.service || true

clean:
	rm -f -- krenewd

krenewd: krenewd.cpp Makefile
	g++ -Wall -Wextra -std=c++20 -flto=4 -Os -fwhole-program -o $@ krenewd.cpp
