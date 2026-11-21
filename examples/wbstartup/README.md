# A Workbench program

A program that runs from a shell and from Workbench, and takes its greeting
from the `GREETING` tool type of its icon, as
[Workbench programs](../../doc/wbstartup.md) in the User's Manual explains.

| file | |
|---|---|
| `hello.c` | the program |
| `Makefile` | builds it, and runs it under volamos from a shell and as Workbench does |

```shell
make CC=/path/to/m68k-amigaos-gcc
make check VOLAMOS=/path/to/volamos
```

`make check` starts `hello` from a shell, and as Workbench does with
`hello.c` as a project. volamos doesn't read icons, so both keep the default
greeting. On AmigaOS, give `hello` a tool icon (for example a copy of a tool's
`.info`), add `GREETING=Ciao` to its tool types in Workbench's Information
window, and double-click it.
