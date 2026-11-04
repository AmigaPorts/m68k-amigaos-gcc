CC = m68k-amigaos-gcc
CRT = newlib
CFLAGS = -Os -mcrt=$(CRT) -Wall -Wextra

all: hello

# libpthread, the AROS pthreads port, comes with the toolchain for libnix and
# newlib.  -s strips the symbols, which an AmigaOS program doesn't need.
hello: hello.c
	$(CC) $(CFLAGS) -s -o $@ $< -lpthread

clean:
	rm -f hello

.PHONY: all clean
