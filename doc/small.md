Part of the [Amiga GCC User's Manual](manual.md).

# Small programs

Most of a small program is the C runtime it links: the startup code, and the
library functions it calls. Then come the options that change the code.

## The C runtime

[C runtimes](runtimes.md#size) lists the size of the same programs with each
runtime. libnix (`-mcrt=nix20`, or `-mcrt=nix13` for Kickstart 1.3) makes the
smallest: an empty program is under 2 KB, against about 6 KB with newlib and
15 KB with clib2. `-mcrt=library` keeps most of libnix in `libnix4.library`, shared by
the programs that use it.

## Options

| option | for |
|---|---|
| `-Os` | the smallest code gcc can make |
| `-s` | strips the debug symbols, which a program doesn't need to run |
| `-fbaserel` | a4-relative data: shorter instructions and fewer relocations, see [options.md](options.md#addressing-data) |
| `-mpcrel` | PC-relative references: fewer relocations, see [options.md](options.md#code-model) |
| `-msmall-code` | 16-bit branches only, see [options.md](options.md#code-model) |
| `-flto` | link-time optimization: inlines functions across source files and drops unreachable symbols, see [below](#-flto) |
| `-mregparm=N` | passes the first N arguments in registers: shorter calls, see [below](#-mregparmn) |
| `-Wl,--gc-sections` | drops the unused functions and variables of libstdc++, see [below](#-wl--gc-sections) |
| `-ffunction-sections -fdata-sections -Wl,--gc-sections` | drops unreferenced functions and variables, see [below](#-ffunction-sections--fdata-sections--wl--gc-sections) |
| `-fno-exceptions`, `-fno-rtti` | C++ without exception handling or type information in the program's own code, see [C++](#c) |
| `-m68020-60` | 68020 instructions, such as 32-bit multiplication and division, instead of calls; the program no longer runs on a 68000, see [options.md](options.md#cpu-and-fpu) |
| `-m68881` | with a 68020 or later CPU, FPU instructions instead of the software floating point in libgcc and libm |

`puts("hello, world")` with libnix and `-Os -s` is 5436 bytes, and 4668 with
`-fbaserel`. `-mpcrel` and `-msmall-code` change little with a C runtime: its
libraries are built without them. The program without startup code below is
188 bytes, and 168 with `-mpcrel`.

`-m68020-60` and `-m68881` shrink a program that computes: one with a loop
of 32-bit multiplications and divisions, `sqrt()`, `sin()` and `pow()` is
5452 bytes with libnix and `-Os -s`, 5284 with `-m68020-60`, and 4524 with
`-m68020-60 -m68881`. But libnix's FPU libm is built for speed, not size:
`printf()` with `-lm` grows by about 7 KB with `-m68881`, see
[C runtimes](runtimes.md#libnix).

The following options are most effective on larger programs, which consist
of many functions and source files. Each places requirements on the
program.

### -flto

Enables Link Time Optimizations: gcc optimizes the whole program at link
time, inlining functions across source files. A program that consists of a
single source file is unaffected.

- Pass `-flto` both when compiling and when linking, with the same `-O`
  option.
- gcc drops unreachable symbols, such as functions that are never called
  and global variables that are never referenced. Mark with
  `[[gnu::used]]` the symbols that are reached in a way the compiler cannot
  see, from an `asm()` string or by scanning the program:
  - the entry point of a program without startup code, such as `start()`
    below;
  - a `$VER:` string;
  - the Resident structure of a library or device.

### -mregparm=N

Passes the first N arguments of each kind in registers instead of on the
stack, see [abi.md](abi.md#register-arguments). `-mregparm=3` can shrink a
large program by about 3%: [Benchwork results](https://github.com/codewiz/benchwork/blob/main/results/regparm.md).

A function that is called by code built without the option receives its
arguments on the stack, and must be declared `__stdargs`:

- `main()`, which the startup code calls, see [abi.md](abi.md#main-with--mregparm);
- a callback passed to a library, such as the comparison function of
  `qsort()`. gcc warns about these, see [abi.md](abi.md#mixing-conventions);
- a function written in assembler that reads its arguments from the stack.

The functions of the C runtime require no change: its headers declare them
`__stdargs`.

### -Wl,--gc-sections

The linker drops unreferenced sections. On its own, this removes the unused
functions and variables of the libraries built with a section for each of
them, as libstdc++ is, while the program's own code keeps its short calls
between neighboring functions. It makes a C++ program 5% to 7% smaller: the
[std::thread example](../examples/cxx_thread/) goes from 152,496 to 144,848
bytes with `-Os -s`, and the program in [C++](#c) from 158,416 to 147,652.
A C program gains little: newlib, libnix and clib2 have one function in most
of their source files, so the linker already takes only those the program
calls.

A symbol that only something scanning the program finds, such as a `$VER:`
string, stays when it shares a section with code the program uses. In a
source file of its own, such as a `version.c`, it is dropped: name it as in
the second point below.

### -ffunction-sections -fdata-sections -Wl,--gc-sections

This simpler technique is superseded by `-flto`. It often makes programs
slower, because it requires long jumps even between functions that are
defined in the same source file: the program below grows from 188 to 204
bytes.

The compiler places each function and variable in a section of its own, and
the linker drops unreferenced sections. It is useful when the source files
contain more code than the program uses, as with a library taken from
another project.

- All three options are required: without `-Wl,--gc-sections`, the other
  two only make the program slightly larger.
- In a program linked with a C runtime, the linker also drops symbols that
  are found by scanning the program, even those marked `[[gnu::used]]`: a
  `$VER:` string, or the Resident structure of a library or device. Make
  such a symbol global and name it with `-Wl,-u,_<symbol>`.
  `[[gnu::retain]]`, which keeps such symbols on ELF targets, is not
  supported by the m68k-amigaos target: it relies on an ELF section flag
  that the Hunk object format lacks.
- A program without startup code is a special case. The linker drops
  nothing from it, and with `-flto` it drops everything: `-Wl,-u,_start`
  keeps the entry point of the program below, and each `$VER:` string
  needs its own `-Wl,-u`.

## C++

| option | effect |
|---|---|
| `-fno-exceptions` | no exception handling: `throw` and `try` are errors, and the program has no exception tables |
| `-fno-rtti` | no type information: `dynamic_cast` and `typeid` are errors |

Both apply to the program's own code only. libstdc++ is built with
exceptions and type information, and links its exception handling, about
20 KB, as soon as the program uses something that can throw, such as a
`std::vector` that grows or `new`. This program is 158,416 bytes with
newlib and `-Os -s`, 157,752 with both options, and 146,988 with
`-Wl,--gc-sections` too:

```c++
#include <cstdio>
#include <memory>
#include <vector>

struct Shape {
    virtual ~Shape() = default;
    virtual int area() const = 0;
};

struct Square : Shape {
    int side;
    explicit Square(int s) : side(s) {}
    int area() const override { return side * side; }
};

int main()
{
    std::vector<std::unique_ptr<Shape>> shapes;
    for (int i = 1; i <= 4; i++) {
        shapes.push_back(std::make_unique<Square>(i));
    }

    int total = 0;
    for (const auto &s : shapes) {
        total += s->area();
    }
    std::printf("%d\n", total);
    return 0;
}
```

The two options save more in a program with many classes and functions of
its own.

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
