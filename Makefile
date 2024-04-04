.PHONY: all clean

all: krenewd

clean:
	rm -f -- krenewd

krenewd: krenewd.cpp Makefile
	g++ -Wall -Wextra -std=c++20 -flto=4 -Os -o $@ krenewd.cpp
