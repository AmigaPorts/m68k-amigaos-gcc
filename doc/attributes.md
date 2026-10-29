Part of the [Amiga GCC User's Manual](manual.md).

# Keywords and attributes

## Keywords

The compiler predefines these keywords, each a macro for an attribute, as
SAS/C has them:

| keyword | on | effect |
|---|---|---|
| `__chip` | variable | in chip memory, where the custom chips can reach it |
| `__fast` | variable | in fast memory |
| `__far` | variable | addressed absolutely, also in [base-relative code](options.md#addressing-data), so it doesn't count against the 64 KB a4 reaches |
| `__near` | variable | in the ordinary data section: a4-relative in base-relative code |
| `__saveds` | function | loads its own a4 on entry, for a function called with someone else's, such as a hook or a callback: see [options.md](options.md#addressing-data) |
| `__regargs` | function | arguments in registers: `__attribute__((regparm(2)))`, see [abi.md](abi.md#register-arguments) |
| `__stdargs` | function | arguments on the stack, also with `-mregparm`: `__attribute__((stkparm))` |
| `__saveallregs` | function | saves and restores every register, d0 included, so the function can't return a value: use it only on `void` functions |
| `__entrypoint` | function | saves no registers, not even those a caller expects to keep |
| `__interrupt` | function | returns with `rte`, for a raw 68000 exception vector. Exec interrupt servers and handlers (`AddIntServer()`, `SetIntVector()`) are ordinary functions that return with `rts`: don't use it for them |
| `__stackext` | function | accepted and ignored: there is no stack extension |

Chip and fast variables go into sections of their own, which the linker turns
into hunks with that memory type. Far variables also get their own section, of
any memory type, outside the data that a4 reaches.

## Arguments in registers

`__regargs`, `__stdargs`, `__attribute__((regparm(N)))` and parameters that
name their register, such as `LONG value __asm("d2")`, are explained with
the other calling conventions in [abi.md](abi.md).
