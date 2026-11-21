// A program without startup code or C runtime. AmigaOS starts a program at
// its first instruction, with the arguments in a0 and their length in d0,
// and takes d0 back as the return code. The library bases are local
// variables: SysBase from address 4, DOSBase opened here.

// The program starts at the first byte of its code, and gcc may put other
// code and constants such as strings before start(): jump over them. gcc
// emits top-level asm before the functions of a file, so this comes first,
// as long as this file comes first on the link command line.
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
