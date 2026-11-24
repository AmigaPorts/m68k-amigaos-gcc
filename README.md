# m68k-amigaos-gcc

The GNU C Compiler with binutils and other useful tools for cross compiling software for AmigaOS.
This is the AmigaPorts continuation of bebbo's amiga-gcc; fixes flow both ways.

* [Amiga GCC User's Manual](doc/manual.md): using the toolchain, and its Amiga-specific options, attributes and C runtimes.
* [Amiga GCC Development Manual](doc/devel.md): building, packaging, testing and releasing the toolchain, its branches, and making changes to it.

Currently, these tools are bundled:

* binutils with Hunk binary format support
* gcc with frontends for C/C++/ObjC; the experimental Rust frontend (gccrs) builds with `make ADDLANG=rust` (see [examples/rust](examples/rust/))
* libnix, newlib, clib2
* sfdc, with fd2sfd for FD files
* fd2pragma
* vbcc, vasm, vlink
* ira (m68k reassembler)
* zlib, libpng, freetype
* Various Amiga SDKs (see [sdk](sdk/))

## Copyrights

See [COPYING](COPYING) and [COPYING-THIRD-PARTY](COPYING-THIRD-PARTY.md).
