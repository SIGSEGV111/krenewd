.PHONY: all clean install

all: krenewd

install: krenewd
	sudo install krenewd         /usr/local/bin/

clean:
	rm -f -- krenewd

krenewd: krenewd.cpp Makefile
	clang++ -Wall -Wextra -std=gnu++20 -flto -Os -o $@ krenewd.cpp
