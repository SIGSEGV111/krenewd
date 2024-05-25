.PHONY: all clean install

all: krenewd

install: krenewd
	sudo install krenewd         /usr/local/bin/

clean:
	rm -f -- krenewd

krenewd: krenewd.cpp Makefile
	g++ -Wall -Wextra -std=c++20 -flto=4 -Os -fwhole-program -o $@ krenewd.cpp
