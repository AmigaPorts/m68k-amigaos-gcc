Part of the [Amiga GCC User's Manual](manual.md).

# Calling conventions

How functions pass their arguments and return values: on the stack, in
registers the compiler picks, or in registers the function names. The
[options](options.md#register-arguments) and [keywords](attributes.md)
that choose between them are listed on their own pages; this page explains
and compares them.

## Registers

| registers | use | kept across calls |
|---|---|---|
| d0, d1, a0, a1, fp0, fp1 | scratch, arguments in registers, return values | no |
| d2-d7, a2, a3, fp2-fp7 | the function's own | yes |
| a4 | the data base in [base-relative](options.md#addressing-data) code | yes |
| a5 | the frame pointer, unless `-fomit-frame-pointer` | yes |
| a6 | the library base when calling AmigaOS libraries | yes |
| a7 | the stack pointer | |

## Return values

| type | returned in |
|---|---|
| integers and pointers | d0 |
| `long long`, structures of up to 8 bytes | d0 and d1 |
| larger structures | memory: the caller passes its address in a1 |
| `float` and `double` | fp0 with `-m68881`; d0, or d0 and d1, without |

## Stack arguments

By default, every argument goes on the stack: pushed from the last to the
first, each taking at least 4 bytes, and removed by the caller. This is what
code compiled without any of the options below does, and what C runtimes,
libraries and other compilers expect unless their headers say otherwise.

`__stdargs`, or `__attribute__((stkparm))`, keeps a function on the stack
also in code compiled with `-mregparm`. The runtimes' headers declare their
functions this way, so they keep working when a program uses register
arguments.

## Register arguments

`-mregparm` on the command line, or `__regargs` (`__attribute__((regparm(2)))`)
on a function, passes the first arguments in registers:

- up to two integers in d0 and d1;
- up to two pointers in a0 and a1;
- with an FPU, up to two floating point values in fp0 and fp1;
- an integer or pointer with no register of its kind left takes a free one
  of the other kind;
- the rest go on the stack.

`-mregparm=N` and `regparm(N)` allow N of each kind. `-msasregparm` puts an
integer or pointer that finds its own kind full on the stack, as SAS/C's
`__regargs` does. Register arguments make code about 3% smaller and up to
10% faster on call-heavy code ([Benchwork](https://github.com/codewiz/benchwork/blob/main/results/regparm.md)).

## Arguments in named registers

A parameter can name its register, as AmigaOS library functions and hooks
take their arguments:

```c
LONG MyFunc(LONG value __asm("d2"), struct Node *node __asm("a2"));
```

The caller puts each argument in its register; the function saves the
registers that it must keep, d2 and a2 here, as usual.

A hook, for example, is called with the hook in a0, the object in a2 and
the message in a1:

```c
ULONG hook_func(struct Hook *h __asm("a0"), APTR obj __asm("a2"), APTR msg __asm("a1"));
```

In base-relative code it also needs `__saveds`, because the OS calls it
with someone else's a4.

## Calling AmigaOS libraries

A library function takes the library base in a6 and its arguments in the
registers its `.fd` or `.sfd` file names. The NDK's `proto/` headers do this:
`#include <proto/exec.h>` declares exec's functions as macros that load
those registers and call through the library base, with no stubs to link.
A library function may change d0, d1, a0 and a1, and returns its result in
d0.

## Mixing conventions

The caller and the function have to agree, so every caller must see the
function's own prototype: a call through a prototype without `__regargs`
passes the arguments on the stack, where a register function doesn't look
for them, and the program reads garbage. The compiler warns when a pointer
to a function is converted to a pointer to a function with another
convention:

```
warning: conversion between pointers to functions with different calling conventions [-Wcallconv-mismatch]
```

### main() with -mregparm

The startup code of every runtime calls `main()` with its arguments on the
stack, so with `-mregparm` `main()` reads `argc` and `argv` from registers
that hold something else. Declare it with `__stdargs`:

```c
int __stdargs main(int argc, char **argv)
```

## SAS/C

`-msasregparm -mmangle-regparm` makes gcc's register functions take their
arguments where SAS/C's `__regargs` functions do, and gives them SAS/C's
`@name` symbols, so that objects of the two compilers call each other.
Integer, pointer, `char`, `short` and, with an FPU, `double` arguments
match, in registers and on the stack. They don't match for:

- functions without arguments: SAS/C calls them `@name` and gcc `_name`;
- arguments in named registers, which the two compilers name differently;
- structures passed or returned by value.

Two linker issues also get in the way. SAS/C's default `code=near` calls
with `bsr.w`, which can't reach gcc's functions in another hunk: build the
SAS/C code with `code=far`. And ld reads SAS/C's `HUNK_DREL32` relocations
as a4-relative, where SAS/C's own linker reads them as absolute.

The details, and the tests that check all this against SAS/C 6.58, are in
gcc's [sas/README](https://github.com/AmigaPorts/gcc/blob/amiga16.2/gcc/testsuite/gcc.target/m68k/amigaos/sas/README).
