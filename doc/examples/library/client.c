/// Calls `hello.library`. `hello_autoopen.c` defines `HelloBase`, so the
/// startup code opens the library before `main()` and closes it at exit.

#include <proto/hello.h>
#include <stdio.h>

/// The minimum version of every library the startup code opens; without it, 0.
/// Uncomment to refuse to start unless hello.library is version 2 or later.
// long __oslibversion = 2;

int main()
{
	// The macros of inline/hello.h call through HelloBase, in a6.  The library
	// keeps its own copy of the greeting, and copies it back into a buffer of
	// ours.
	char greeting[32];

	HelloGetGreeting(greeting, sizeof greeting);
	printf("%s, ", greeting);

	if (!HelloSetGreeting("World"))
		return 20;

	HelloGetGreeting(greeting, sizeof greeting);
	printf("%s\n", greeting);

	return 0;
}
