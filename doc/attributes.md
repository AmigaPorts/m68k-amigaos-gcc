# Keywords, attributes and predefined macros

Part of the [Amiga GCC User's Manual](manual.md).

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
| `__regargs` | function | arguments in registers: `__attribute__((regparm(2)))`, see below |
| `__stdargs` | function | arguments on the stack, also with `-mregparm`: `__attribute__((stkparm))` |
| `__saveallregs` | function | saves and restores every register, d0 included, so the function can't return a value: use it only on `void` functions |
| `__entrypoint` | function | saves no registers, not even those a caller expects to keep |
| `__interrupt` | function | returns with `rte`, for a raw 68000 exception vector. Exec interrupt servers and handlers (`AddIntServer()`, `SetIntVector()`) are ordinary functions that return with `rts`: don't use it for them |
| `__stackext` | function | accepted and ignored: there is no stack extension |

Chip and fast variables go into sections of their own, which the linker turns
into hunks with that memory type. Far variables also get their own section, of
any memory type, outside the data that a4 reaches.

## Arguments in registers

`__regargs`, or `__attribute__((regparm(N)))`, passes up to N integers in d0,
d1, ... and up to N pointers in a0, a1, ...; with an FPU, also up to N floating
point values in fp0, fp1, ... An integer or pointer with no register of its kind
left takes a free one of the other kind. With `-msasregparm`, it goes on the
stack instead, as SAS/C's `__regargs` does. The [options](options.md#register-arguments)
`-mregparm` and `-msasregparm` do the same for every function.

A parameter can also name its register, as AmigaOS library functions take
their arguments:

```c
LONG MyFunc(LONG value __asm("d2"), struct Node *node __asm("a2"));
```

The caller puts each argument in its register; the function saves the
registers that the ABI says it must keep, d2 here and a2, as usual.

Every caller has to see the same prototype as the function: a call through a
prototype without the attribute passes the arguments on the stack, where the
function doesn't look for them.

## Predefined macros

Always defined:

- `amiga`, `amigaos`, `amigaos3`, `AMIGA`, `MCH_AMIGA`, each also with leading
  `__`, and with leading and trailing `__`, such as `__amiga__`
- `mc68000`, `__mc68000__`, `__m68k__`

By option:

| option | defines |
|---|---|
| `-mcrt=nix20` | `__libnix__` (also `__libnix`, `libnix`) |
| `-mcrt=nix13` | `__libnix__`, and `__KICK13__` |
| `-mcrt=clib2` | `__CLIB2__` (also `__CLIB2`, `CLIB2`) |
| `-mcrt=ixemul` | `__ixemul__` (also `__ixemul`, `ixemul`) |
| `-mcrt=newlib` | nothing; newlib's headers define `__NEWLIB__` |
| `-m68020` ... `-m68060` | `__mc68020__` ... `__mc68060__` (also `mc68020`, `__mc68020`, ...) |
| `-m68881`, `-mhard-float` | `__HAVE_68881__` |
| `-fbaserel` | `__baserel__` |
| `-fbaserel32` | `__baserel__` and `__baserel32__` |

Without `-m68881`, `__HAVE_68881__` isn't defined, also for the 68040 and 68060:
the code then uses no FPU instructions.

`m68k-amigaos-gcc <options> -dM -E - </dev/null` lists all the macros the
compiler predefines for a set of options.
