# A program without startup code

A program that prints its arguments with exec and dos.library alone, with
no startup code or C runtime, as [Small programs](../../doc/small.md) in the
User's Manual explains.

| file | |
|---|---|
| `hello.c` | the program |
| `Makefile` | builds it, and runs it under volamos |

```shell
make CC=/path/to/m68k-amigaos-gcc
make check VOLAMOS=/path/to/volamos
```
