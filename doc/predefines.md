Part of the [Amiga GCC User's Manual](manual.md).

# Predefined macros

Always defined:

- `__amigaos__`, `__amiga__`, `__AMIGA__`, `__amigaos3__`
- `__mc68000__`, `__m68k__`

By option:

| option | defines |
|---|---|
| `-mcrt=nix20` | `__libnix__` |
| `-mcrt=nix13` | `__libnix__`, `__KICK13__` |
| `-mcrt=clib2` | `__CLIB2__` |
| `-mcrt=ixemul` | `__ixemul__` |
| `-mcrt=newlib` | nothing; newlib's headers define `__NEWLIB__` |
| `-m68010` | `__mc68010__` |
| `-m68020` | `__mc68020__` |
| `-m68030` | `__mc68030__` |
| `-m68040` | `__mc68040__` |
| `-m68060` | `__mc68060__` |
| `-m68020-40` | `__mc68020__`, `__mc68030__`, `__mc68040__` |
| `-m68020-60` | `__mc68020__`, `__mc68030__`, `__mc68040__`, `__mc68060__` |
| `-m68881`, `-mhard-float` | `__HAVE_68881__` |
| `-fbaserel` | `__baserel__` |
| `-fbaserel32` | `__baserel__`, `__baserel32__` |
| `-pthread` | `_REENTRANT` |

`_REENTRANT` is what `-pthread` defines on other targets too. libnix has a
thread-safe variant, with a per-thread `errno` and locked stdio, which its
headers select with `__posix_threads__`; the compiler doesn't define it, so
programs and libnix itself use the plain variant
([#224](https://github.com/AmigaPorts/m68k-amigaos-gcc/issues/224)).

`__HAVE_68881__` tells whether the code uses FPU instructions: it follows
`-m68881`, not the CPU, so `-m68040` and `-m68060` alone don't define it.

The keywords `__chip`, `__saveds`, `__regargs` and the others are predefined
macros too: see [attributes.md](attributes.md).

`m68k-amigaos-gcc <options> -dM -E - </dev/null` lists all the macros the
compiler predefines for a set of options.

## Deprecated macros

Each macro above also comes in older spellings, which new code shouldn't use:

- without the leading and trailing `__`: `amiga`, `amigaos`, `amigaos3`,
  `AMIGA`, `mc68000`, `mc68020`, ..., `libnix`, `CLIB2`, `ixemul`;
- with only the leading `__`: `__amiga`, `__libnix`, `__mc68020`, ...;
- `MCH_AMIGA`, `__MCH_AMIGA` and `__MCH_AMIGA__`, from Manx Aztec C. `AMIGA`
  is what SAS/C defines.

The unprefixed names aren't reserved for the implementation, so they can
collide with identifiers in a program. A strict standard mode, such as
`-std=c99`, `-std=c11`, `-std=c23` or `-std=c++17` instead of the default
`gnu` modes, removes the unprefixed system and CPU macros; the runtime ones
stay.
