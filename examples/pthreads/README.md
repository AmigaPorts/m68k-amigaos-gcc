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
| newlib | 69 KB | `malloc()` and stdio are safe, and `errno` is each thread's own, with a toolchain built with the default `THREADS=amigaos`, not with `THREADS=no` (see [Thread model](../../doc/build.md#thread-model)) |
| nix20 | 14 KB | `malloc()` is safe; stdio and `errno` aren't |

So this program locks around `printf()` itself. It runs on an Amiga, an
emulator, or volamos:

```
1> hello
Hello, World from thread 1
Hello, World from thread 2
Hello, World from thread 3
Hello, World from thread 4
All 4 threads are done
```

[cxx_thread](../cxx_thread/) is the same program with `std::thread`.

## Torture test

`pthreads-torture` tests newlib with threads that never wait, so that only
the end of a time slice switches them. Each one checks that `errno` and
`strtok()` stay its own, keeps heap blocks filled with its own pattern, and
writes whole lines to one shared `FILE`, which the program reads back at the
end. It needs a toolchain built with `THREADS=amigaos`, and isn't built by
default:

```shell
make CC=/path/to/m68k-amigaos-gcc pthreads-torture
```

The program counts the task switches it saw inside its busy loops. Without
any it tested nothing, as under volamos, which switches tasks only when one
waits: that's why `make check` doesn't run it. Run it on a real Kickstart, in
an emulator or on a machine. On an emulated 68040, this run takes about five
minutes:

```
1> pthreads-torture 8 2000
pthreads-torture: 8 threads, 2000 rounds, 131 task switches seen: 0 failures
```

The arguments are the number of threads (up to 16), the rounds each runs,
and the length of the busy loop. It writes `pthreads-torture.out` in the
current directory.
