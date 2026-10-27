# Amiga GCC User's Manual

<p align="center"><img src="cover.png" width="424" alt="The GNU bursting out of an Amiga monitor at a knight in armour typing at the keyboard"></p>

Using the m68k-amigaos toolchain to build programs, libraries and devices for
AmigaOS. GCC's own manual covers everything else; these pages cover what is
specific to the Amiga.

- [Compiler and linker options](options.md): choosing a C runtime, the data
  models, register arguments, libraries and devices, CPU and FPU.
- [C runtimes](runtimes.md): libnix, newlib, clib2 and ixemul compared.

## Getting started

A program for Kickstart 2.0 and later, on any 68000 Amiga:

```shell
m68k-amigaos-gcc -mcrt=nix20 -Os -o hello hello.c
```

The options worth choosing early:

- the C runtime, the same for every object and the link: `-mcrt=nix20`
  unless you need another one;
- the CPU: `-m68020-60` for code that is fast on the A1200, A3000 and
  A4000, accelerated Amigas and emulators, but no longer runs on a 68000;
  `-m68881` to use the FPU;
- `-fbaserel` for smaller, faster code, or `-resident` for a program that
  can be made resident.
