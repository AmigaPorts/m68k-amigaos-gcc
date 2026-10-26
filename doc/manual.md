# Amiga GCC User's Manual

Using the m68k-amigaos toolchain to build programs, libraries and devices for
AmigaOS. GCC's own manual covers everything else; these pages cover what is
specific to the Amiga.

- [Compiler and linker options](options.md): choosing a C runtime, the data
  models, register arguments, libraries and devices, CPU and FPU.

## Getting started

A program for Kickstart 2.0 and later, on any 68000 Amiga:

```shell
m68k-amigaos-gcc -mcrt=nix20 -Os -o hello hello.c
```

The options worth choosing early:

- the C runtime, the same for every object and the link: `-mcrt=nix20`
  unless you need another one;
- the CPU: `-m68020` or later for code that only runs on those, and
  `-m68881` to use the FPU;
- `-fbaserel` for smaller, faster code, or `-resident` for a program that
  can be made resident.
