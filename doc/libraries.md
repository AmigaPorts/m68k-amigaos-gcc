Part of the [Amiga GCC User's Manual](manual.md).

# Libraries

Calling AmigaOS libraries, and building your own.

## Calling a library

`#include <proto/intuition.h>` declares intuition.library's functions as macros that
load the arguments into their registers and call through `IntuitionBase` in
a6. [abi.md](abi.md#calling-amigaos-libraries) has the register rules.

Two link libraries, which every program gets without asking, cover the rest:

- `libamiga.a` is an open-source equivalent of the NDK's amiga.lib: a
  function for each library call, for code that calls without the macros; the
  `_LVO` offsets, for assembler sources; and support functions such as
  `CreatePort()` and `DoMethod()`. It is built as part of libnix, and newlib
  and ixemul link it too; clib2 has its own.
- `libstubs.a`, with libnix and newlib, has the library bases that the startup
  code opens, as below.

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

    if (IntuitionBase == nullptr) {
        return 20;
    }

    // ...

    CloseLibrary((struct Library *)IntuitionBase);
    return 0;
}
```

### Library bases that aren't global variables

The calls can go through a base other than the global one:

- **Speed and size.** Any library call may change memory, so the compiler
  loads a global base again before each call: `move.l _GfxBase,a6`, or
  `move.l _GfxBase:W(a4),a6` with `-fbaserel`. A base in a local variable or a
  parameter is loaded into a6 once, and stays there from call to call, since
  libraries preserve a6. For the three calls below, that is 48 bytes of code
  instead of 64, or 56 with `-fbaserel`.
- **Libraries calling themselves or other libraries.** A library function
  gets its own base as an argument, and calls the library's other functions
  through it. The global variables of a library are shared by all the tasks
  that call it, so a base that it opens for each of them goes in its own
  library base, or is passed from function to function as an argument.
- **Threads.** bsdsocket.library gives each task that opens it a base of its
  own, so a program whose threads use sockets keeps a base for each thread.

Macros defined before the first `#include <proto/...>` choose the base:

| Macro | The calls use as the base |
|---|---|
| `__NOLIBBASE__` | the variable named like the base, such as `GfxBase`, that is in scope where the call is; the proto headers don't declare the global bases |
| `<LIBRARY>_BASE_NAME`, such as `BSDSOCKET_BASE_NAME` or `DOS_BASE_NAME` | the expression it expands to, in place of the name of the base |

Defining them after the `#include` is too late: the header has already chosen
the base. Without `__NOLIBBASE__`, the functions with a variable number of
arguments, such as `syslog()`, `SocketBaseTags()` and `Printf()`, are defined
in the header and expand `<LIBRARY>_BASE_NAME` there, so it must be valid
outside any function. With `__NOLIBBASE__`, each call expands it, and it can
use the function's parameters and variables. `__NOLIBBASE__` applies to all
the proto headers that the file includes, so the file declares any global base
it still uses, such as `SysBase`.

A function that gets the base as a parameter, and loads it into a6 once for
the three calls:

```c
#define __NOLIBBASE__
#include <proto/graphics.h>

void draw_corner(struct GfxBase *GfxBase, struct RastPort *rp)
{
    Move(rp, 0, 0);
    Draw(rp, 10, 0);
    Draw(rp, 10, 10);
}
```

A library that keeps a bsdsocket.library base for each opener in its own
base:

```c
#define __NOLIBBASE__
#define BSDSOCKET_BASE_NAME (lb->SocketBase)
#include <proto/bsdsocket.h>

struct MyLibBase {
    struct Library lib;
    struct Library *SocketBase;
};

LONG my_close(struct MyLibBase *lb, LONG sock)
{
    return CloseSocket(sock);
}
```

A program that looks up the base of the calling thread:

```c
struct Library *GetSocketBase(void);

#define BSDSOCKET_BASE_NAME GetSocketBase()
#include <proto/bsdsocket.h>
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

[examples/library](../examples/library/) builds `hello.library` and a program
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

LONG __stdargs __UserLibInit(struct Library *lib, [[maybe_unused]] REG(a4, APTR dataseg))
{
    SysBase = ((__LIB)lib)->SysBase;
    InitSemaphore(&lock);
    return 0;
}

void __stdargs __UserLibCleanup([[maybe_unused]] REG(a4, APTR dataseg))
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
