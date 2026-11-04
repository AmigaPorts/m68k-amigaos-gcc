# POSIX threads

Hello, World from four POSIX threads, which take turns at `printf()` with a
`pthread_mutex_t`.

```shell
make CC=/path/to/m68k-amigaos-gcc
make CC=/path/to/m68k-amigaos-gcc CRT=nix20
```

libpthread, a port of the AROS pthreads library, comes with the toolchain for
newlib and libnix; clib2 has no pthreads. Each thread is an AmigaOS process,
which shares the program's console and current directory. Threads need OS 2.0.

| runtime | size | C library across threads |
|---|---:|---|
| newlib | 69 KB | `malloc()` and stdio are safe |
| nix20 | 14 KB | `malloc()` is safe; stdio and `errno` aren't, so this program locks around `printf()` itself |

volamos runs a single task, so this one runs on an Amiga or an emulator:

```
1> hello
Hello, World from thread 1
Hello, World from thread 2
Hello, World from thread 3
Hello, World from thread 4
All 4 threads are done
```

[cxx_thread](../cxx_thread/) is the same program with `std::thread`.
