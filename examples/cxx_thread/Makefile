CXX = m68k-amigaos-g++
CXXFLAGS = -Os -mcrt=newlib -Wall -Wextra

all: hello

# std::thread needs a toolchain built with THREADS=amigaos, and a C library
# whose malloc() and stdio are safe across tasks: newlib.  -s strips the
# symbols, which an AmigaOS program doesn't need.
hello: hello.cc
	$(CXX) $(CXXFLAGS) -s -o $@ $<

clean:
	rm -f hello

.PHONY: all clean
