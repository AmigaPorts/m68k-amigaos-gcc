/// `hello.library`, built with `-ramiga-lib`.

#include <exec/semaphores.h>
#include <exec/types.h>
#include <proto/exec.h>
#include <libinit.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>

/// The libnix startup code puts these in the romtag and the library base:
/// the name programs open the library by, its version string and version.
/// They, and `__UserLibInit()` and `__UserLibCleanup()`, keep the AmigaOS
/// types `<libinit.h>` declares them with; the library's own interface uses
/// C's.
const char LibName[] = "hello.library";
const char LibIdString[] = "hello.library 1.0 (30.10.2026)";
const UWORD LibVersion = 1;
const UWORD LibRevision = 0;

/// A library has no startup code to set `SysBase`: `__UserLibInit()` does.
struct ExecBase *SysBase;

/// The library's globals: absolute data, one copy per loaded library, shared
/// by every program that opens it, so `lock` guards `greeting`.
static struct SignalSemaphore lock;
static char *greeting;

/// Called once, when the library is loaded, before the first `OpenLibrary()`
/// returns: return 0 on success, anything else to fail the load.
LONG __stdargs __UserLibInit(struct Library *lib, [[maybe_unused]] REG(a4, APTR dataseg))
{
	SysBase = ((__LIB)lib)->SysBase;
	InitSemaphore(&lock);
	return 0;
}

/// Called once, when the library is expunged, after the last `CloseLibrary()`
/// once memory is needed: free what the library allocated.  Not at each
/// close: the next opener expects the greeting still there.
void __stdargs __UserLibCleanup([[maybe_unused]] REG(a4, APTR dataseg))
{
	FreeVec(greeting);
}

/// Keeps a copy of `s`, in memory of the library's own: the caller's string
/// may go away before the next call.  Returns `false` if out of memory.
///
/// Like every library function, it takes its arguments in the registers that
/// `hello_lib.sfd` names, and runs on the caller's task.
bool HelloSetGreeting(REG(a0, const char *s))
{
	size_t size = strlen(s) + 1;
	char *copy = AllocVec(size, MEMF_ANY);

	if (!copy)
		return false;
	memcpy(copy, s, size);

	ObtainSemaphore(&lock);
	char *old = greeting;
	greeting = copy;
	ReleaseSemaphore(&lock);

	FreeVec(old);
	return true;
}

/// Copies the greeting last set, or "Hello", into the caller's `buffer` of
/// `size` bytes, cut short if needed and always terminated, as `GetVar()`
/// does: a pointer into the library's copy could be freed by the next
/// `HelloSetGreeting()` of another program.  Returns the greeting's length.
size_t HelloGetGreeting(REG(a0, char *buffer), REG(d0, size_t size))
{
	ObtainSemaphore(&lock);
	size_t len = strlcpy(buffer, greeting ? greeting : "Hello", size);
	ReleaseSemaphore(&lock);
	return len;
}

/// The jump table after the standard vectors, in the order of `hello_lib.sfd`:
/// `HelloSetGreeting()` is at -30, the bias, `HelloGetGreeting()` 6 bytes
/// further at -36.  22 puts the entries in the code: like the
/// `ADD2LIST()` lists of constructors, the jump table is a `.list_` section,
/// which the linker collects and sorts by name; 24 would put them in the data.
ADD2LIST(HelloSetGreeting, __FuncTable__, 22);
ADD2LIST(HelloGetGreeting, __FuncTable__, 22);
ADDTABL_END();
