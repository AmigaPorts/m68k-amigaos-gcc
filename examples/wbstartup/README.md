# A Workbench program

A program that runs from a shell and from Workbench, and takes its greeting
from the `GREETING` tool type of its icon, as
[Workbench programs](../../doc/wbstartup.md) in the User's Manual explains.

| file | |
|---|---|
| `hello.c` | the program |
| `Makefile` | builds it, and runs it from a shell under volamos |

```shell
make CC=/path/to/m68k-amigaos-gcc
make check VOLAMOS=/path/to/volamos
```

volamos can't start a program as Workbench does, so `make check` runs only the
shell side, where `hello` has no icon and keeps its default greeting. On
AmigaOS, give `hello` a tool icon (for example a copy of a tool's `.info`), add
`GREETING=Ciao` to its tool types in Workbench's Information window, and
double-click it.
