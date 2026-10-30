# hello.library

An AmigaOS library, `hello.library`, and a program that calls it, as
[Libraries](../../libraries.md) in the User's Manual explains.

| file | |
|---|---|
| `hello_lib.sfd` | the library's interface, from which sfdc generates the headers |
| `hello.c` | the library |
| `client.c` | the program |
| `Makefile` | builds both, and runs the program under volamos |

```shell
make CC=/path/to/m68k-amigaos-gcc SFDC=/path/to/sfdc
make check VOLAMOS=/path/to/volamos
```
