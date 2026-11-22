CXX = m68k-amigaos-g++
VOLAMOS = volamos
CXXFLAGS = -Os -mcrt=newlib -pthread -Wall -Wextra

all: hello

# std::thread needs a toolchain built with THREADS=amigaos, and a C library
# whose malloc() and stdio are safe across tasks: newlib, with -pthread.  -s
# strips the symbols, which an AmigaOS program doesn't need.
hello: hello.cc
	$(CXX) $(CXXFLAGS) -s -o $@ $<

# Runs the program under volamos, which checks every memory access: out of
# bounds, after free, and below the stack pointer.
check: all
	$(VOLAMOS) --sanitize hello > check.out
	grep -x "All 4 threads are done" check.out

clean:
	rm -f hello check.out

.PHONY: all check clean
