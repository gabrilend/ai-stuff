#ifndef DIRECT_H_COMPAT
#define DIRECT_H_COMPAT

// Compatibility header for Windows direct.h on Linux
// Provides POSIX equivalents for Windows directory functions

#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <limits.h>

// Directory function mappings
#define _mkdir(path) mkdir(path, 0755)
#define _rmdir rmdir
#define _getcwd getcwd
#define _chdir chdir

// Path constants
#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

#ifndef MAX_PATH
#define MAX_PATH PATH_MAX
#endif

#endif // DIRECT_H_COMPAT