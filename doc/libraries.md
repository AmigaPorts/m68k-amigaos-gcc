Part of the [Amiga GCC User's Manual](manual.md).

# Libraries

Calling AmigaOS libraries, and building your own.

## Calling a library

`#include <proto/intuition.h>` declares intuition.library's functions as macros that
load the arguments into their registers and call through `IntuitionBase` in
a6. [abi.md](abi.md#calling-amigaos-libraries) has the register rules.

### Opened by the startup code

With libnix and newlib, the startup code opens the libraries a program uses.
A program that references a library base, such as `IntuitionBase`, without
defining it links that base from `libstubs.a`, and the startup code opens the
library before `main()` and closes it at exit:

- `libstubs.a` has the libraries of the NDK, the ReAction classes and some
  resources.
- If a library is missing, the program prints `intuition.library failed to
  load` and exits with 20.

The program can require a minimum version for all the auto-opened libraries
by defining a global variable; the default is 0, no minimum version:

```c
// Open every library at version 39 (AmigaOS 3.0) or later, or fail at startup
long __oslibversion = 39;
```

clib2 and ixemul don't support the auto-open mechanism: the link fails on the
undefined base.

### Opened by the program

To require a different version for each library, or with clib2 and ixemul,
the program defines the base and opens the library itself. Its definition
takes the place of the one in `libstubs.a`:

```c
#include <proto/exec.h>
#include <proto/intuition.h>

struct IntuitionBase *IntuitionBase;

int main()
{
	IntuitionBase = (struct IntuitionBase *)OpenLibrary("intuition.library", 39);
	if (!IntuitionBase)
		return 20;
	// ...
	CloseLibrary((struct Library *)IntuitionBase);
	return 0;
}
```

### Libraries outside the NDK

sfdc, installed with the toolchain, generates a library's headers from its
`.sfd` file, as [below](#the-interface); its
[manual](https://github.com/AmigaPorts/sfdc/blob/master/SFDCompile.pod)
lists all it can generate. `sfdc --mode=autoopen` also writes the base for
the startup code to open:

```c
__attribute__((section(".dlist___LIB_LIST__")))
void* HelloBase[2] = { (void*)-1, "hello.library" };
```

The generated file defines it only for libnix: with newlib, compile that file
alone with `-D__libnix__`.

## Creating a library

[examples/library](examples/library/) builds `hello.library` and a program
that calls it: `make` there builds both, and `make check` runs the program
under volamos.

### The interface

The `.sfd` file describes the functions, their registers and their order in
the jump table:

```
==base _HelloBase
==basetype struct Library *
==libname hello.library
==bias 30
==public
==include <exec/types.h>
LONG HelloAdd(LONG a, LONG b) (d0,d1)
STRPTR HelloName() ()
==end
```

sfdc generates the headers for the callers, and the base for the startup code
to open:

```shell
sfdc --mode=clib -o include/clib/hello_protos.h hello_lib.sfd
sfdc --mode=macros -o include/inline/hello.h hello_lib.sfd
sfdc --mode=proto -o include/proto/hello.h hello_lib.sfd
sfdc --mode=autoopen -o hello_autoopen.c hello_lib.sfd
```

### The library

`-ramiga-lib` links libnix's library startup code in place of a program's:
the romtag, the initialization, and the Open, Close and Expunge vectors. It
needs libnix, `-mcrt=nix20` or `-mcrt=nix13`. The library defines the rest,
which `<libinit.h>` declares:

| | |
|---|---|
| `LibName`, `LibIdString` | the name it is opened by, and its version string |
| `LibVersion`, `LibRevision` | its version |
| `__UserLibInit()` | called when the library is loaded; returns 0 on success |
| `__UserLibCleanup()` | called when it is expunged |
| `ADD2LIST(f, __FuncTable__, 22)` | adds `f` to the jump table: one for each function, in the order of the `.sfd` file |
| `ADDTABL_END()` | ends the jump table |

```c
#include <exec/types.h>
#include <libinit.h>

const char LibName[] = "hello.library";
const char LibIdString[] = "hello.library 1.0 (30.10.2026)";
const UWORD LibVersion = 1;
const UWORD LibRevision = 0;

LONG HelloAdd(REG(d0, LONG a), REG(d1, LONG b))
{
	return a + b;
}

/* ... __UserLibInit(), __UserLibCleanup() and HelloName() */

ADD2LIST(HelloAdd, __FuncTable__, 22);
ADD2LIST(HelloName, __FuncTable__, 22);
ADDTABL_END();
```

```shell
m68k-amigaos-gcc -O2 -mcrt=nix20 -Wall -Wextra -ramiga-lib -o hello.library hello.c
```

The functions run on the caller's task and stack. Global data is one copy
for every opener.

## Devices

`-ramiga-dev` links libnix's device startup code. A device is built like a
library, with these names instead, also declared in `<libinit.h>`:

| | |
|---|---|
| `DevName`, `DevIdString` | the name it is opened by, and its version string |
| `DevVersion`, `DevRevision` | its version |
| `__UserDevInit()` | called when the device is loaded; returns non-zero on success, unlike `__UserLibInit()` |
| `__UserDevOpen()` | called for each `OpenDevice()`; returns 0 on success |
| `__UserDevClose()` | called for each `CloseDevice()` |
| `__UserDevCleanup()` | called when it is expunged |

Its jump table continues with `BeginIO` and `AbortIO`, added with
`ADD2LIST()` and ended with `ADDTABL_END()`, as for a library.
