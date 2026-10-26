# Compiler and linker options

Part of the [Amiga GCC User's Manual](manual.md).

The options that m68k-amigaos-gcc adds to GCC's own. `m68k-amigaos-gcc --help=target`
lists them with one line each.

## Choosing a C runtime

| option | runtime |
|---|---|
| `-mcrt=nix20` | libnix, for Kickstart 2.0 and later: the usual choice |
| `-mcrt=nix13` | libnix for Kickstart 1.3, with the NDK 1.3 headers from `ndk13-include`; defines `__KICK13__` |
| `-mcrt=newlib` | newlib: the default without `-mcrt=` |
| `-mcrt=clib2` | clib2 |
| `-mcrt=ixemul` | ixemul: needs `ixemul.library` at run time |
| `-mcrt=library` | libnix as a shared library: needs `libnix4.library` at run time |
| `-noixemul` | the same as `-mcrt=nix20`, under an older name: prefer `-mcrt=nix20` |

Pass the same `-mcrt=` when compiling and when linking. It picks the headers
when compiling, and the startup code and libraries when linking, so an object
compiled for one runtime and linked with another breaks quietly. Passing two
runtimes is an error.

## Addressing data

By default, code reaches global and static data by absolute address, and the
loader relocates those addresses when it loads the program. The base-relative
models address data relative to register a4 instead, which the startup code
loads:

| option | data model |
|---|---|
| `-fbaserel` | a4-relative with 16-bit offsets: up to 64 KB of data and BSS |
| `-fbaserel32` | a4-relative with 32-bit offsets, for more data; needs the 68020 or later |
| `-resident` | as `-fbaserel`, and linked as a pure program: each run gets its own copy of the data, so one copy of the code can be made resident with `Resident` |
| `-resident32` | as `-fbaserel32`, linked as a pure program |

Base-relative code is smaller and faster than absolute code. The whole
program, libraries included, must use one data model: the driver links the
matching variant of each runtime library.

A function that is called with someone else's a4, such as a hook, an
interrupt handler or a callback passed to the OS, must load its own a4 before
it touches data:

| option | loads a4 in |
|---|---|
| `__saveds` on the function | that function |
| `-mrestore-a4` | every public function |
| `-malways-restore-a4` | every function, static ones included |

They load a4 with `___restore_a4` from the startup code, and keep the
caller's. Pure programs (`-resident`) can't use them: a4 depends on which run
of the program calls.

## Code

`-msmall-code` keeps function addresses out of registers and makes the
assembler reject a branch too far for a 16-bit displacement. It doesn't
change the code otherwise.

## Register arguments

By default, arguments are passed on the stack. These options pass some of
them in registers instead:

| option | arguments in registers |
|---|---|
| `-mregparm` | up to two integers in d0/d1, two pointers in a0/a1 and, with an FPU, two floating point values in fp0/fp1 |
| `-mregparm=N` | up to N of each kind |
| `-msasregparm` | the same registers as SAS/C's `__regargs`: the first two integers, pointers and floating point values; the rest on the stack |
| `-mmangle-regparm` | names functions taking register arguments after their registers, as SAS/C does, so that SAS/C objects link with them |

Code compiled with and without these options can't call each other's
functions unless their prototypes say how they take their arguments.

## Libraries, devices and threads

| option | links |
|---|---|
| `-ramiga-lib` | a shared library: libnix's library startup code instead of a program's |
| `-ramiga-libr` | a shared library whose data is copied for each opener |
| `-ramiga-dev` | a device |
| `-pthread` | the POSIX threads library |

The `-ramiga-*` options need libnix (`-mcrt=nix20` or `-mcrt=nix13`).

## CPU and FPU

Code runs on the 68000 by default. `-m68020`, `-m68030`, `-m68040` and
`-m68060` (or `-mcpu=`) allow the instructions of that CPU, and the result
no longer runs on a lesser one.

Floating point code uses the FPU only with `-m68881` (or `-mhard-float`),
also on the 68040 and 68060, whose FPU is built in. Without it, floating
point is done in software.

The driver links the runtime libraries built for the options:

| options | libraries |
|---|---|
| none, or `-m68010` | 68000 |
| `-m68020` to `-m68060` | 68020 |
| `-m68020` to `-m68060` with `-m68881` | 68020 with FPU |
| `-fbaserel`, `-resident` | base-relative 68000 |
| `-fbaserel` or `-resident` with `-m68020` to `-m68060` | base-relative 68020, with FPU for `-m68881` |
| `-fbaserel32`, `-resident32` with `-m68020` to `-m68060` | 32-bit base-relative 68020, with FPU for `-m68881` |

`m68k-amigaos-gcc -print-multi-lib` lists them, and
`m68k-amigaos-gcc <options> -print-multi-directory` names the one a set of
options picks.

## Debugging

`-g` writes DWARF debugging information into a debug hunk of the executable,
which `m68k-amigaos-gdb` reads. AmigaOS ignores it when loading the program;
`m68k-amigaos-strip` removes it.
