# C runtimes

Part of the [Amiga GCC User's Manual](manual.md).

A program links one C runtime, chosen with `-mcrt=` when compiling and when
linking: see [options.md](options.md#choosing-a-c-runtime).

| runtime | option | for |
|---|---|---|
| libnix | `-mcrt=nix20` | native Amiga programs, Kickstart 2.0 and later: small executables |
| libnix | `-mcrt=nix13` | Kickstart 1.3 |
| libnix | `-mcrt=library` | the same, in the shared `libnix4.library` |
| newlib | `-mcrt=newlib` | portable code: good POSIX and C99 compatibility and some C11 and C23 features, but larger executables |
| ixemul | `-mcrt=ixemul` | Unix programs: ixemul.library emulates much of a Unix system |
| clib2 | `-mcrt=clib2` | unmaintained, with gaps and some known bugs; it will be removed in a later release unless someone takes it over |

<!-- TODO: per-runtime sections: the C and POSIX standards each supports and
what it lacks (math, long double, locale, wide characters, threads, Workbench
startup), and where they behave differently on the same AmigaOS handle, such
as fstat() on consoles and pipes. -->

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

## ixemul

ixemul.library comes in builds for each CPU, with and without FPU. Code
compiled with `-m68881` needs one of the FPU builds: it expects floating
point results in an FPU register.
