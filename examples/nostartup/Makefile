CC = m68k-amigaos-gcc
VOLAMOS = volamos
CFLAGS = -Os -Wall -Wextra
# -mpcrel makes it smaller still: 168 bytes stripped, against 188. -fbaserel
# needs the startup code, which loads a4 and puts the data in its reach.
#CFLAGS += -mpcrel

all: hello

# -nostdlib: no startup code (-nostartfiles) and no libraries
# (-nodefaultlibs), only what hello.c defines. Add -lgcc for the arithmetic
# helpers gcc may call, such as 32-bit multiplication and division on the
# 68000.
hello: hello.c
	$(CC) $(CFLAGS) -nostdlib -o $@ $<

# Runs the program under volamos with two arguments, and checks every memory
# access: out of bounds, after free, and below the stack pointer.
check: all
	$(VOLAMOS) --sanitize hello one two > check.out
	grep "^Hello, World, with the arguments: one two" check.out

clean:
	rm -f hello check.out

.PHONY: all check clean
