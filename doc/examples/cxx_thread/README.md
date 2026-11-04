# std::thread

Hello, World from four C++ threads, which take turns at `printf()` with a
`std::mutex`.

```shell
make CXX=/path/to/m68k-amigaos-g++
```

Each `std::thread` is an AmigaOS process, which shares the program's console
and current directory. Threads need OS 2.0 and a C library whose `malloc()` and
stdio are safe across tasks, which is newlib: libnix and clib2 can start
threads, but their own functions aren't safe to call from several of them.

The program is about 190 KB: `std::thread` reports a failure to start with a
`std::system_error`, which brings in the exception support even with
`-fno-exceptions`. It doesn't use `std::cout` or `std::print`, which would add
almost a megabyte.

```
1> hello
Hello, World from thread 1
Hello, World from thread 2
Hello, World from thread 3
Hello, World from thread 4
All 4 threads are done
```
