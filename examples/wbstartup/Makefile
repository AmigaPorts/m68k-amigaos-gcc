CC = m68k-amigaos-gcc
VOLAMOS = volamos
CFLAGS = -Os -mcrt=nix20 -Wall -Wextra

all: hello

hello: hello.c
	$(CC) $(CFLAGS) -o $@ $<

# Runs the program under volamos, from a shell and as Workbench starts it,
# where a project file selected with it comes in the WBStartup message, with
# a lock on its directory: Work:, this one.  volamos doesn't read icons, so the
# greeting is the default; from a shell an argument replaces it.  volamos
# checks every memory access.
check: all
	$(VOLAMOS) --sanitize hello > check.out
	grep -x "Hello, Shell!" check.out
	$(VOLAMOS) --sanitize hello Ciao > check.out
	grep -x "Ciao, Shell!" check.out
	$(VOLAMOS) --sanitize --workbench -V Work:. hello hello.c > check.out
	grep -x "Hello, Workbench!" check.out
	grep -x "project: hello.c" check.out

clean:
	rm -f hello check.out

.PHONY: all check clean
