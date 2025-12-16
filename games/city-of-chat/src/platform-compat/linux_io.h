#ifndef LINUX_IO_H
#define LINUX_IO_H

// Linux compatibility layer for Windows io.h
// Provides POSIX equivalents for Windows-specific I/O functions

#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <stdio.h>

// Windows to POSIX file access mappings
#define _access access
#define _close close
#define _open open
#define _read read
#define _write write
#define _lseek lseek
#define _tell tell
#define _filelength filelength

// File access mode constants
#ifndef F_OK
#define F_OK 0  // File exists
#endif
#ifndef R_OK
#define R_OK 4  // Read permission
#endif
#ifndef W_OK
#define W_OK 2  // Write permission
#endif
#ifndef X_OK
#define X_OK 1  // Execute permission
#endif

// File open flags
#ifndef O_BINARY
#define O_BINARY 0  // No binary mode distinction on POSIX
#endif
#ifndef O_TEXT
#define O_TEXT 0    // No text mode distinction on POSIX
#endif

// POSIX equivalent function implementations
static inline long tell(int fd) {
    return lseek(fd, 0, SEEK_CUR);
}

static inline long filelength(int fd) {
    struct stat st;
    if (fstat(fd, &st) == 0) {
        return st.st_size;
    }
    return -1;
}

// Additional Windows compatibility
#define _stricmp strcasecmp
#define _strnicmp strncasecmp
#define stricmp strcasecmp
#define strnicmp strncasecmp

// Directory separators
#define PATH_SEP '/'
#define PATH_SEP_STR "/"

#endif // LINUX_IO_H