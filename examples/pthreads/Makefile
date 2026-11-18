CC = m68k-amigaos-gcc
VOLAMOS = volamos
CRT = newlib
CFLAGS = -Os -mcrt=$(CRT) -pthread -Wall -Wextra

all: hello

# -pthread links libpthread, the AROS pthreads port, which comes with the
# toolchain for libnix and newlib.  -s strips the symbols, which an AmigaOS
# program doesn't need.
hello: hello.c
	$(CC) $(CFLAGS) -s -o $@ $<

# Runs the program under volamos, which checks every memory access: out of
# bounds, after free, and below the stack pointer.
check: all
	$(VOLAMOS) --sanitize hello > check.out
	grep -x "All 4 threads are done" check.out

clean:
	rm -f hello check.out

.PHONY: all check clean
