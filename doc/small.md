Part of the [Amiga GCC User's Manual](manual.md).

# Small programs

Most of a small program is the C runtime it links: the startup code, and the
library functions it calls. Then come the options that change the code.

## The C runtime

[C runtimes](runtimes.md#size) lists the size of the same programs with each
runtime. libnix (`-mcrt=nix20`, or `-mcrt=nix13` for Kickstart 1.3) makes the
smallest: an empty program is under 2 KB, against 13 to 15 KB with newlib or
clib2. `-mcrt=library` keeps most of libnix in `libnix4.library`, shared by
the programs that use it.

## Options

| option | for |
|---|---|
| `-Os` | the smallest code gcc can make |
| `-s` | strips the debug symbols, which a program doesn't need to run |
| `-fbaserel` | a4-relative data: shorter instructions and fewer relocations, see [options.md](options.md#addressing-data) |
| `-mpcrel` | PC-relative references: fewer relocations, see [options.md](options.md#code-model) |
| `-msmall-code` | 16-bit branches only, see [options.md](options.md#code-model) |
| `-flto` | link-time optimization: inlines and drops functions across source files |
| `-mregparm=3` | arguments in registers: shorter calls, see [abi.md](abi.md#register-arguments) |
| `-m68020-60` | 68020 instructions, such as 32-bit multiplication and division, instead of calls; the program no longer runs on a 68000, see [options.md](options.md#cpu-and-fpu) |
| `-m68881` | with a 68020 or later CPU, FPU instructions instead of the software floating point in libgcc and libm |

`puts("hello, world")` with libnix and `-Os -s` is 5436 bytes, and 4668 with
`-fbaserel`. `-mpcrel` and `-msmall-code` change little with a C runtime: its
libraries are built without them. The program without startup code below is
188 bytes, and 168 with `-mpcrel`.

`-flto` and `-mregparm` help most with larger programs which are broken into
multiple functions and source files. Register arguments alone can shrink a
large program by about 3%: [Benchwork results](https://github.com/codewiz/benchwork/blob/main/results/regparm.md).

When using `-mregparm`, declare `main()` as `__stdargs`: the startup code passes
its arguments on the stack, see [abi.md](abi.md#main-with--mregparm).

`-m68020-60` and `-m68881` shrink a program that computes: one with a loop
of 32-bit multiplications and divisions, `sqrt()`, `sin()` and `pow()` is
5452 bytes with libnix and `-Os -s`, 5284 with `-m68020-60`, and 4524 with
`-m68020-60 -m68881`. But libnix's FPU libm is built for speed, not size:
`printf()` with `-lm` grows by about 7 KB with `-m68881`, see
[C runtimes](runtimes.md#libnix).

## Without startup code

A program that calls only AmigaOS libraries needs no C runtime at all.
[examples/nostartup](../examples/nostartup/) prints its arguments with
exec and dos.library alone, in 188 bytes with `-Os -s`:

```c
__asm__("\t.text\n\tjra _start");

#define __NOLIBBASE__
#include <proto/exec.h>
#include <proto/dos.h>

// used: only the asm above calls it, which -flto doesn't see
[[gnu::used]] LONG start(STRPTR args __asm("a0"), LONG len __asm("d0"))
{
    // Load a local SysBase variable from AbsExecBase. The absolute address
    // 4 is in slow Chip memory, and can be even slower on systems running
    // MuForce or similar debug tools.
    struct ExecBase *SysBase = *(struct ExecBase **)4;

    // V34 is Kickstart 1.3. Output() and Write() are in every version, so 0
    // would work too, and OldOpenLibrary() would save a few more bytes.
    struct Library *DOSBase = OpenLibrary((CONST_STRPTR)"dos.library", 34);

    if (DOSBase == nullptr) {
        return RETURN_FAIL;
    }

    static const char msg[] = "Hello, World, with the arguments: ";
    BPTR out = Output();
    Write(out, (APTR)msg, sizeof(msg) - 1);
    Write(out, args, len);

    CloseLibrary(DOSBase);
    return RETURN_OK;
}
```

```shell
m68k-amigaos-gcc -Os -s -nostdlib -o hello hello.c
```

`-nostdlib` is `-nostartfiles`, no startup code, and `-nodefaultlibs`, no
libraries.

What the startup code otherwise does is up to the program:

- AmigaOS starts a program at the first byte of its code, with the arguments
  in a0, their length in d0, and the return code taken from d0. gcc may put
  strings and other functions before `start()`, so a jump to it comes first:
  gcc emits top-level `asm` before the functions of a file. With several
  source files, the one with the jump goes first on the link command line.
- No library is opened for it: exec's base is at address 4, and the program
  opens the others. With `__NOLIBBASE__`, local variables named like the
  bases do, see [Libraries](libraries.md#library-bases-that-arent-global-variables).
- `-nostdlib` leaves out libgcc too: add `-lgcc` when gcc calls its
  arithmetic helpers, such as 32-bit multiplication and division on the
  68000, or 64-bit arithmetic.
- `-fbaserel` needs the startup code, which loads a4 and puts the data in
  its reach: without it, a program with global variables fails to link.
  `-mpcrel` needs nothing.
- Started from Workbench, a program gets a message it must reply to before
  it exits. This one runs only from a shell.
