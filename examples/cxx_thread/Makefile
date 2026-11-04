CXX = m68k-amigaos-g++
CXXFLAGS = -Os -mcrt=newlib -Wall -Wextra

all: hello

# Threads need a C library whose malloc() and stdio are safe across tasks:
# newlib.  -s strips the symbols, which an AmigaOS program doesn't need.
hello: hello.cc
	$(CXX) $(CXXFLAGS) -s -o $@ $<

clean:
	rm -f hello

.PHONY: all clean
