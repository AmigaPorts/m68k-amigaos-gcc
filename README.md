# m68k-amigaos-gcc

The GNU C Compiler with binutils and other useful tools for cross compiling software for AmigaOS.
This is the AmigaPorts continuation of bebbo's amiga-gcc; fixes flow both ways.

Currently, these tools are built:

* binutils with Hunk binary format support
* gcc with frontends for C/C++/ObjC; the experimental Rust frontend (gccrs) builds with `make ADDLANG=rust`, which needs cargo (see `rust-demo/`)
* libnix, newlib, clib2
* sfdc, fd2sfd, fd2pragma
* vbcc, vasm, vlink
* ira (m68k reassembler)

## Documentation

* [Amiga GCC User's Manual](doc/manual.md): using the toolchain, and its Amiga-specific options, attributes and C runtimes.
* [Amiga GCC Development Manual](doc/devel.md): building, packaging, testing and releasing the toolchain, and making changes to it.

## Branches
### Notable branches of gcc
* `amiga6`: The legacy GCC 6.5.0b
* `amiga13.4`: GCC 13.4, unsupported but still widely used
* `amiga16.2`: GCC 16.2, the default branch, built and tested by CI

### Notable branches of binutils
* `amiga-2.46`: binutils 2.46 with amigaos support and dwarf2 debugging (the default)

## Copyrights

See [COPYING](COPYING) and [COPYING-THIRD-PARTY](COPYING-THIRD-PARTY.md).
