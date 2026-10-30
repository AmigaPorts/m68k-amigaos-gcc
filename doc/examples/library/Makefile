CC = m68k-amigaos-gcc
SFDC = sfdc
VOLAMOS = volamos
CFLAGS = -O2 -mcrt=nix20 -Wall -Wextra

all: hello.library client

# -ramiga-lib links libnix's library startup code instead of a program's:
# the romtag, the init code and the standard vectors.
hello.library: hello.c
	$(CC) $(CFLAGS) -ramiga-lib -o $@ $<

client: client.c hello_autoopen.c include/proto/hello.h
	$(CC) $(CFLAGS) -Iinclude -o $@ client.c hello_autoopen.c

# The headers callers include, generated from the .sfd file:
# the prototypes (clib/), the macros that call through HelloBase (inline/),
# and proto/hello.h, which includes both and declares HelloBase.
include/proto/hello.h: hello_lib.sfd
	mkdir -p include/clib include/inline include/proto
	$(SFDC) -q --mode=clib -o include/clib/hello_protos.h $<
	$(SFDC) -q --mode=macros -o include/inline/hello.h $<
	$(SFDC) -q --mode=proto -o $@ $<

# Defines HelloBase in the list of libraries the libnix and newlib startup code
# opens before main(), so the client needs no OpenLibrary().
hello_autoopen.c: hello_lib.sfd
	$(SFDC) -q --mode=autoopen -o $@ $<

# Runs the client under volamos, which loads hello.library from the current
# directory instead of LIBS:, and checks every memory access of the client and
# the library: out of bounds, after free, and below the stack pointer.
check: all
	$(VOLAMOS) --sanitize --libs-dir . client 2>&1 | tee check.out
	test "$$(cat check.out)" = "Hello, World"

clean:
	rm -rf include hello_autoopen.c hello.library client check.out

.PHONY: all check clean
