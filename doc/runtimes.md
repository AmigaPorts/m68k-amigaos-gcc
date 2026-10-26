# C runtimes

Part of the [Amiga GCC User's Manual](manual.md).

A program links one C runtime, chosen with `-mcrt=`:

| option | runtime | for |
|---|---|---|
| `-mcrt=nix20` | libnix | native Amiga programs, Kickstart 2.0 and later: the recommended choice, with the smallest executables |
| `-mcrt=nix13` | libnix | the same for Kickstart 1.3, with the NDK 1.3 headers from `ndk13-include`; defines `__KICK13__` |
| `-mcrt=library` | libnix | the same as `nix20`, in the shared `libnix4.library` |
| `-mcrt=newlib` | newlib | the default without `-mcrt=`: portable code, with good POSIX and C99 compatibility and some C11 and C23 features, but larger executables |
| `-mcrt=ixemul` | ixemul | Unix programs: `ixemul.library` emulates much of a Unix system |
| `-mcrt=clib2` | clib2 | unmaintained, with gaps and some known bugs; it will be removed in a later release unless someone takes it over |
| `-noixemul` | libnix | the same as `-mcrt=nix20`, under an older name: prefer `-mcrt=nix20` |

**Important:** pass the same `-mcrt=` when compiling and when linking. It
picks the headers when compiling, and the startup code and libraries when
linking, so an object compiled for one runtime and linked with another
breaks quietly.

## Size

The executables built with `-Os`, stripped, in bytes:

| runtime | `int main(void) { return 0; }` | `printf("hello, world\n")` |
|---|---|---|
| `-mcrt=nix20` | 2032 | 5832 |
| `-mcrt=nix13` | 2368 | 6176 |
| `-mcrt=library` | 2036 | 2452, plus `libnix4.library` |
| `-mcrt=newlib` | 13572 | 17140 |
| `-mcrt=clib2` | 15340 | 15780 |
| `-mcrt=ixemul` | 4340 | 4388, plus `ixemul.library` |

<!-- TODO: the size of a typical C program, and the speed of the runtimes. -->

## libnix

**Standards:** C99, including all of the C99 math functions.
<!-- TODO: POSIX coverage, and what C11 and C23 adds. -->

**C++ and OS support:** C++ works; the g++ testsuite runs on libnix.
Kickstart 2.0 and later, or 1.3 with `-mcrt=nix13`.

**Strengths:** the smallest executables. The default board of the
testsuites, so every compiler change is tested on it; its own tests run with
`make check-libnix`.

**Issues:** C++ `thread_local` variables are not per thread ([#224](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/224)).
<!-- TODO: other known gaps. -->

## newlib

**Standards:** good POSIX and C99 compatibility, and some C11 and C23
features.
<!-- TODO: which ones, and what is missing. -->

**C++ and OS support:** C++ works; the g++ testsuite runs on newlib too.
<!-- TODO: the minimum Kickstart. -->

**Strengths:** the widest standards coverage. newlib's own testsuite runs
with `make check-newlib`, and the gcc testsuites have newlib boards.

**Issues:** larger executables. `nexttoward()` is wrong on the smallest
subnormals and `fma()` is not fused ([newlib-cygwin#23](https://github.com/AmigaPorts/newlib-cygwin/pull/23)).

## ixemul

**Standards:** much of a Unix system, emulated by `ixemul.library`.
<!-- TODO: POSIX coverage. -->

**C++ and OS support:** constructors don't run, neither C++ global
constructors nor C `__attribute__((constructor))` functions
([#234](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/234)), so most
C++ programs don't work.
<!-- TODO: the minimum Kickstart. -->

**Strengths:** ports of Unix programs need few changes. The gcc C testsuite
runs on it in `make check`.

**Issues:** programs need `ixemul.library` 80 or later at run time.
`ixemul.library` comes in builds for each CPU, with and without FPU: code
compiled with `-m68881` needs one of the FPU builds, because it expects
floating point results in an FPU register. In `-m68881` code, floating point
rounds toward zero at double precision, so results differ from the other
runtimes.

## clib2

**Standards:**
<!-- TODO -->

**C++ and OS support:**
<!-- TODO -->

**Strengths:**
<!-- TODO -->

**Issues:** unmaintained, and no testsuite runs on it. `va_start` breaks
variadic functions that GCC inlines ([#188](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/188)).

<!-- TODO: a section on where the runtimes behave differently on the same
AmigaOS handle, such as fstat() on consoles and pipes. -->
