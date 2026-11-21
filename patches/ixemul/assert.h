/* Allow this file to be included multiple times
   with different settings of NDEBUG.  */
#undef assert
#undef __assert

#ifdef NDEBUG
#define assert(ignore) ((void) 0)
#else

/* Reported through ixemul's own stdio. libgcc's __eprintf, which this used to
   call, writes to newlib's stderr and does not link against ixemul.  */
#include <stdio.h>
#include <stdlib.h>

#define assert(expression)  \
  ((void) ((expression) ? 0 : __assert (#expression, __FILE__, __LINE__)))

#define __assert(expression, file, line)  \
  (fprintf (stderr, "%s:%u: failed assertion `%s'\n",	\
	    file, line, expression), abort (), 0)

#endif
