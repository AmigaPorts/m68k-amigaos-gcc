#ifndef CLIB_DTCLASS_PROTOS_H
#define CLIB_DTCLASS_PROTOS_H

/* The one function of a DataTypes class library.  The NDK has
   dtclass_lib.fd, but no prototype for it. */

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

#ifndef  INTUITION_CLASSES_H
#include <intuition/classes.h>
#endif

Class * __stdargs ObtainEngine( VOID );

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* CLIB_DTCLASS_PROTOS_H */
