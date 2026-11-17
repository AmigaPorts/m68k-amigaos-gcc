CC = m68k-amigaos-gcc
VOLAMOS = volamos
CFLAGS = -Os -mcrt=nix20 -Wall -Wextra

all: hello

hello: hello.c
	$(CC) $(CFLAGS) -o $@ $<

# Runs the program from a shell under volamos, which can't start it the
# way Workbench does: without an icon the greeting is the default, and an
# argument replaces it.  volamos checks every memory access.
# Disabled until a volamos release has icon.library
# (https://github.com/sidick/volamos/pull/314); starting the program as
# Workbench does is https://github.com/sidick/volamos/issues/345.
check: all
#	$(VOLAMOS) --sanitize hello > check.out
#	grep -x "Hello, Shell!" check.out
#	$(VOLAMOS) --sanitize hello Ciao > check.out
#	grep -x "Ciao, Shell!" check.out

clean:
	rm -f hello check.out

.PHONY: all check clean
