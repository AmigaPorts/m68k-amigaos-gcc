#include <errno.h>
#include <stddef.h>
#include <string.h>

/*
 * GCC 16's bootstrap libstdc++ currently expects glibc's internal XSI
 * strerror_r entry point.  nix20 provides strerror(), so keep this shim
 * local to the statically linked host compiler programs.
 */
int
__xpg_strerror_r(int error_number, char *buffer, size_t buffer_size)
{
  const char *message = strerror(error_number);
  size_t length;

  if (message == NULL)
    return EINVAL;

  length = strlen(message);
  if (buffer_size == 0)
    return ERANGE;

  if (length >= buffer_size)
    {
      memcpy(buffer, message, buffer_size - 1);
      buffer[buffer_size - 1] = '\0';
      return ERANGE;
    }

  memcpy(buffer, message, length + 1);
  return 0;
}
