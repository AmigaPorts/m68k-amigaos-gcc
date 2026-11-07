CC = m68k-amigaos-gcc
CRT = newlib
CFLAGS = -Os -mcrt=$(CRT) -pthread -Wall -Wextra

all: hello

# -pthread links libpthread, the AROS pthreads port, which comes with the
# toolchain for libnix and newlib.  -s strips the symbols, which an AmigaOS
# program doesn't need.
hello: hello.c
	$(CC) $(CFLAGS) -s -o $@ $<

clean:
	rm -f hello

.PHONY: all clean
