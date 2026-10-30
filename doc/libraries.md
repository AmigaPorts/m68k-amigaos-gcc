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
==include <stdbool.h>
==include <stddef.h>
bool HelloSetGreeting(const char *greeting) (a0)
size_t HelloGetGreeting(char *buffer, size_t size) (a0,d0)
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
| `ADD2LIST(f, __FuncTable__, 22)` | adds `f` to the jump table: one for each function, in the order of the `.sfd` file. 22 puts the entry in the code, 24 in the data: `<stabs.h>`'s lists are sections the linker collects, and the jump table is one of them |
| `ADDTABL_END()` | ends the jump table |

```c
#include <exec/types.h>
#include <libinit.h>

const char LibName[] = "hello.library";
const char LibIdString[] = "hello.library 1.0 (30.10.2026)";
const UWORD LibVersion = 1;
const UWORD LibRevision = 0;

// in the registers of the .sfd file
bool HelloSetGreeting(REG(a0, const char *s))
{
	// ... keep a copy of s
}

// ... __UserLibInit(), __UserLibCleanup() and HelloGetGreeting()

ADD2LIST(HelloSetGreeting, __FuncTable__, 22);
ADD2LIST(HelloGetGreeting, __FuncTable__, 22);
ADDTABL_END();
```

```shell
m68k-amigaos-gcc -O2 -mcrt=nix20 -Wall -Wextra -ramiga-lib -o hello.library hello.c
```

The functions run on the caller's task and stack.

### Data

A library's global variables are absolute data: one copy per loaded library,
shared by every program that opens it, so guard them with a semaphore. The
example keeps a greeting there:

- `__UserLibInit()` sets `SysBase`, which a library has to define itself, as
  it has no startup code to do it;
- `HelloSetGreeting()` stores a copy, in memory allocated with `AllocVec()`:
  libnix's `malloc()` and `strdup()` need the startup code of a program;
- `__UserLibCleanup()` frees it when the library is expunged, not when a
  program closes it: the next opener still expects the greeting there.

```c
struct ExecBase *SysBase;

static struct SignalSemaphore lock;
static char *greeting;

LONG __stdargs __UserLibInit(struct Library *lib, REG(a4, APTR dataseg))
{
	SysBase = ((__LIB)lib)->SysBase;
	InitSemaphore(&lock);
	return 0;
}

void __stdargs __UserLibCleanup(REG(a4, APTR dataseg))
{
	FreeVec(greeting);
}
```

libnix's startup allocates the library base itself, of a fixed size, so a
library can't extend it with fields of its own.

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
