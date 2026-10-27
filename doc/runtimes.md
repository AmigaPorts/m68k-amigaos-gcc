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

## Features

| | libnix | newlib | ixemul | clib2 |
|---|---|---|---|---|
| minimum Kickstart | 2.0 (V36); 1.3 (V34) with `-mcrt=nix13` | 2.0 (V36) | 2.04 (V37) | 2.04 (V37) |
| C99 math | all functions | all functions, with `-lm` | only the C89 functions | `double` and `float` functions |
| `long double` math | computed in `double` | full precision | none | none |
| `long long` | yes | yes | yes | 68020 and up only |
| C11 library | none | `quick_exit()` | none | none |
| C23 library | `strdup()`, `strndup()` | `strdup()`, `strndup()`, `memccpy()`, `<stdbit.h>` | `strdup()`, `strndup()`, `memccpy()` | `strdup()` |
| POSIX files and directories | most | most | most | most |
| `popen()`, `system()` | yes | no | yes | yes |
| `fork()` | no | no | `vfork()` only | no |
| sockets | `-lsocket` | no | yes, with `ixnet.library` | `-lnet` |
| locale | `locale.library` | "C" and "C.UTF-8" | "C" | `locale.library` |
| wide characters and UTF-8 | no | yes, in "C.UTF-8" | no | no |
| threads | `-pthread` | `-pthread` | no | no |
| minimum stack check | `__stack`, with `__stkinit` | no | `__stack` | `__stack_size` |
| stack extension | no | no | no | no |
| C++ | yes | yes | mostly broken | without the standard library |
| Workbench startup | yes | yes | yes | yes |

The minimum stack check gives the program a larger stack at startup when it
gets less than the variable says. Nothing extends the stack while the
program runs: the compiler has no `-mstackextend` or `-mstackcheck`.

The details are in each runtime's section below.

## libnix

**Standards:** C99, including all of the C99 math functions, and most of the
POSIX file, directory and time functions: `open()`, `stat()`, `fstat()`,
`opendir()`, `getcwd()`, `chdir()`, `mkdir()`, `rename()`, `access()`,
`pipe()`, `dup2()`, `realpath()`, `gettimeofday()`, `clock_gettime()`,
`nanosleep()`, `usleep()`, `popen()` and `system()`, `getenv()` and
`setenv()`. Sockets, `select()` and `poll()` are in `libsocket.a`: link with
`-lsocket`. Of C11 and C23, none of `<threads.h>`, `<uchar.h>`,
`aligned_alloc()`, `quick_exit()`, `timespec_get()`, `memccpy()` or
`strfromd()`. The headers are newlib's, so they also declare functions that
libnix doesn't have.

`long double` is 12 bytes with a 64-bit mantissa, but the `long double` math
functions and `strtold()` compute in `double` precision. There is no wide
character I/O, and `mbstowcs()` doesn't decode UTF-8. `setlocale()` opens
`locale.library` locales. `-pthread` links a POSIX threads library.

**C++ and OS support:** C++ works, with exceptions and the standard library;
the g++ testsuite runs on libnix. Kickstart 2.0 and later, or 1.3 with
`-mcrt=nix13`.

**Strengths:** the smallest executables. The default board of the
testsuites, so every compiler change is tested on it; its own tests run with
`make check-libnix`.

**Issues:**
- C++ `thread_local` variables are not per thread ([#224](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/224)).
- Some math functions give wrong results on special cases, such as
  `ceil(-0.5)` and `hypot()` ([#239](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/239)).
- `printf()` doesn't know `%F`: it prints `%F` and takes the next argument
  for the following conversion.
- `strtod()` and `scanf()` don't parse hexadecimal floating point, and
  don't set `ERANGE` on overflow.
- `fork()` always returns 0, as if the caller were the child.
- `memcpy()` calls `CopyMem()`, and the other string functions copy a byte
  at a time.

**Runtime settings:** a program changes these by defining the variable:

| variable | default | effect |
|---|---|---|
| `unsigned long __stack` | none | the minimum stack size: a larger stack is allocated at startup if the program gets less. It takes effect only if the program also references `__stkinit`, for example with `void *keep_stkinit = __stkinit;` after declaring `extern void __stkinit(void);` |
| `const char *__stdiowin` | `"CON://///AUTO/CLOSE/WAIT"` | the console window for a program started from Workbench; none with `-mcrt=nix13` |
| `unsigned *__BUFSIZE` | 8192 | the buffer size of the files the program opens |

## newlib

**Standards:** newlib 4.6. Most of C99, and of C11 and C23
`quick_exit()`, `strdup()`, `memccpy()`, `<stdbit.h>` and `<stdckdint.h>`;
not `aligned_alloc()`, `timespec_get()`, `strfromd()`, `<threads.h>` or
`<uchar.h>`. The math functions are in `libm.a`: link with `-lm`. The
`long double` math functions compute in full 80-bit precision.

Of POSIX, most of the file, directory and time functions: `open()`,
`stat()`, `lstat()`, `fstat()`, `opendir()`, `mkdir()`, `getcwd()`,
`chdir()`, `link()`, `symlink()`, `utime()`, `gettimeofday()`, `sleep()`,
`usleep()`, `getpid()`, and `kill()` for `SIGINT` and `SIGTERM`. None of the
process, pipe and file descriptor functions: `fork()`, `exec*()`, `pipe()`,
`popen()`, `dup()`, `fcntl()`, `access()`, `sigaction()` and
`clock_gettime()` are missing, and `system()` fails with `ENOSYS`.
`getenv()` doesn't see AmigaDOS variables.

`setlocale()` accepts any name; in the "C.UTF-8" locale the multibyte and
wide character functions use UTF-8.

**C++ and OS support:** C++ works, with exceptions and the standard library;
the g++ testsuite runs on newlib too. Kickstart 2.0 and later. `uname()`
needs `workbench.library`.

**Strengths:** the widest standards coverage, and full precision
`long double` math. newlib's own testsuite runs with `make check-newlib`, and
the gcc testsuites have newlib boards.

**Issues:**
- Larger executables: the startup code pulls in stdio, `malloc()` and
  `strstr()` even for an empty program.
- `aligned_alloc()`, `memalign()`, `posix_memalign()` and the other
  `malloc()` extras don't link.
- `printf("%Lf")` converts through `double`, and `strtold()` returns wrong
  values, such as 2 for "2.5".
- `rename()` fails if the destination exists.
- `lstat()` follows soft links ([#215](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/215)).
- `malloc()` isn't thread safe.
- `fma()` with a zero addend rounds twice with `-m68881` ([newlib-cygwin#24](https://github.com/AmigaPorts/newlib-cygwin/pull/24)).

**Runtime settings:** a program changes these by defining the variable:

| variable | default | effect |
|---|---|---|
| `const char *__stdiowin` | `"CON://///AUTO/CLOSE/WAIT"` | the console window for a program started from Workbench |

newlib has no setting for the stack size: set it with the `Stack` command
or in the icon.

## ixemul

**Standards:** much of a 4.4BSD Unix system, emulated by `ixemul.library`:
files and directories, `vfork()` and `exec*()`, `pipe()`, `select()`,
`poll()`, signals with `sigaction()`, `termios`, users and groups, System V
IPC, `glob()`, `regcomp()`, `popen()`, and sockets through `ixnet.library`
and the TCP/IP stack. `fork()` fails with `ENOSYS`, and `mmap()` copies
instead of mapping. Unix paths work: `/` lists the volumes, and `/Work/x` is
`Work:x`.

The math functions are only those of C89. There are no `float` or
`long double` variants, nothing from C99 math or `<fenv.h>`, and none of
C11 and C23. Also missing: `strtof()`, `getline()`, `strtok_r()`,
`localtime_r()`, `getopt_long()`, `getaddrinfo()` and the wide character
functions. `printf()` doesn't know `%a`, `%zu`, `%jd` and `%Lf`.

**C++ and OS support:** constructors don't run, neither C++ global
constructors nor C `__attribute__((constructor))` functions
([#234](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/234)), and
`<cstdio>` doesn't compile, so most C++ programs don't work. Kickstart 2.04
and later.

**Strengths:** ports of Unix programs need few changes. The gcc C testsuite
runs on it in `make check`.

**Issues:** programs need `ixemul.library` 80 or later at run time.
`ixemul.library` comes in builds for each CPU, with and without FPU: code
compiled with `-m68881` needs one of the FPU builds, because it expects
floating point results in an FPU register. In `-m68881` code, floating point
rounds toward zero at double precision, so results differ from the other
runtimes. Also:
- `<sys/signal.h>` declares the signal handler without a prototype, which
  C23, the default, reads as taking no arguments: assigning a handler to
  `sa_handler` needs `-std=gnu17`.
- A non-zero Membuf in `ixemul.prefs` crashes `ixemul.library` 80.1.

**Runtime settings:** a program changes these by defining the variable:

| variable | default | effect |
|---|---|---|
| `unsigned long __stack` | 16384 | the minimum stack size: a larger stack is allocated at startup if the program gets less; `ixstack` changes it in an executable |
| `int ix_expand_cmd_line` | 1 | 0 turns off the expansion of wildcards in the arguments |
| `char *ix_default_wb_window` | none | the console window for a program started from Workbench |

The `ixprefs` program sets the options of `ixemul.library` itself, such as
the translation of `/`, in `ENV:ixemul.prefs`. The environment variables
`USER`, `HOME`, `UID`, `GID` and `TZ` stand in for the user database and
the timezone.

## clib2

**Standards:** C99 except `long double` math, with `<fenv.h>`; none of C11
and C23. On a 68000, there is no 64-bit integer support: `printf("%lld")`
doesn't work and `strtoll()` is missing; the 68020 builds have them.
`printf()` and `scanf()` support floating point only when linked with `-lm`.

Most of the POSIX file and directory functions: `open()`, `stat()`,
`fstat()`, `opendir()`, `getcwd()`, `chdir()`, `mkdir()`, `rename()`,
`realpath()`, `fcntl()`, `dup2()`, `mkstemp()`, `gettimeofday()`,
`usleep()`, `popen()` and `system()`. Signals are `signal()`, `raise()` and
`kill()`, with `SIGINT` from Ctrl-C. No `fork()`, `pipe()`, `sigaction()`,
`clock_gettime()` or threads. `-lunix` adds Unix path semantics, wildcard
expansion of the arguments, `execvp()`, `getopt_long()` and `termios`.
`-lnet` adds sockets through `bsdsocket.library`.

`setlocale()` opens `locale.library` locales. The wide character functions
are stubs.

**C++ and OS support:** C++ compiles and runs, with exceptions and global
constructors, but the standard library headers such as `<iostream>`,
`<string>` and `<vector>` don't compile, because clib2 doesn't define
`max_align_t`. Kickstart 2.04 and later.

**Strengths:** the most startup settings, listed below, Unix path semantics
with `-lunix`, and sockets with `-lnet`.

**Issues:** unmaintained, and no testsuite runs on it.
- `va_start` breaks variadic functions that GCC inlines ([#188](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/188)).
- `-mhard-float -lm` links the soft-float `libm.a` ([#189](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/189)).
- `struct timeval` has no `tv_usec` ([#190](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/190)).
- `tgamma()` returns `lgamma()` ([#225](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/225)).
- clib2's `wchar_t` is `unsigned int`, the compiler's is `long`, so
  `L"..."` strings don't match the wide character functions.
- `<float.h>` describes `long double` as `double`.

**Runtime settings:** a program changes these by defining the variable:

| variable | default | effect |
|---|---|---|
| `unsigned int __stack_size` | 0 | the minimum stack size: a larger stack is allocated at startup if the program gets less |
| `int __priority` | 256: unchanged | the task priority, -128 to 127 |
| `BOOL __detach` | `FALSE` | run in the background, detached from the shell |
| `char *__process_name` | none | the name of the detached process |
| `int __minimum_os_lib_version` | 0: 37 | the minimum version of `dos.library` and `utility.library`, if higher than 37 |
| `char *__minimum_os_lib_error` | none | the message shown if they're older |
| `char *__stdio_window_specification` | none | the console window for a program started from Workbench |
| `BOOL __unix_path_semantics` | `TRUE` | Unix paths with `-lunix` |
| `BOOL __expand_wildcard_args` | `TRUE` | expand wildcards in the arguments |
| `BOOL __check_abort_enabled` | `TRUE` | stop the program on Ctrl-C |
| `BOOL __open_locale` | `TRUE` | open the default locale at startup |
| `BOOL __disable_dos_requesters` | `FALSE` | turn off the "please insert volume" requesters |

## Consoles, files and pipes

`fstat()` tells the kind of an AmigaDOS handle differently in each runtime:

| handle | libnix | newlib | ixemul | clib2 |
|---|---|---|---|---|
| console, `NIL:` | `S_IFCHR` | `S_IFCHR` | `S_IFCHR` | `S_IFCHR` |
| file | `S_IFREG` | `S_IFREG` | `S_IFREG` | `S_IFREG` |
| `PIPE:` | `S_IFCHR` | `S_IFCHR` | `S_IFREG` | fails with `ENOSYS` |

None of them returns `S_IFIFO`, not even ixemul for its own `pipe()`, which
it reports as `S_IFCHR`. To tell a pipe from a console, use `isatty()`: it
is true only for consoles. newlib's `isatty()` is true for file descriptors
0, 1 and 2 whatever they are, and libnix's returns 2 instead of 1. With
`-mcrt=nix13`, `fstat()` reports files and directories as `S_IFLNK`, and
consoles as `S_IFDIR`.
