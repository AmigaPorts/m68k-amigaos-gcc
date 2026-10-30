/// `hello.library`, built with `-ramiga-lib`.

#include <exec/types.h>
#include <libinit.h>

/// The libnix startup code puts these in the romtag and the library base:
/// the name programs open the library by, its version string and version.
const char LibName[] = "hello.library";
const char LibIdString[] = "hello.library 1.0 (30.10.2026)";
const UWORD LibVersion = 1;
const UWORD LibRevision = 0;

/// Called once, when the library is loaded, before the first `OpenLibrary()`
/// returns: return 0 on success, anything else to fail the load.
LONG __stdargs __UserLibInit([[maybe_unused]] struct Library *lib, [[maybe_unused]] REG(a4, APTR dataseg))
{
	return 0;
}

/// Called once, when the library is expunged: free what `__UserLibInit()`
/// allocated.
void __stdargs __UserLibCleanup([[maybe_unused]] REG(a4, APTR dataseg))
{
}

/// The library's functions take their arguments in the registers that
/// `hello_lib.sfd` names, and run on the caller's task.
LONG HelloAdd(REG(d0, LONG a), REG(d1, LONG b))
{
	return a + b;
}

STRPTR HelloName()
{
	return (STRPTR)LibName;
}

/// The jump table after the standard vectors, in the order of `hello_lib.sfd`:
/// `HelloAdd()` is at -30, the bias, and `HelloName()` at -36.
ADD2LIST(HelloAdd, __FuncTable__, 22);
ADD2LIST(HelloName, __FuncTable__, 22);
ADDTABL_END();
