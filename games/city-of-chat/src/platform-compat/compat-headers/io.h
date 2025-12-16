#ifndef IO_H_COMPAT
#define IO_H_COMPAT

// Compatibility header for Windows io.h on Linux
// This file replaces <io.h> with POSIX equivalents

#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <stdio.h>

// Windows to POSIX function mappings
#define _access access
#define _close close
#define _open open
#define _read read
#define _write write
#define _lseek lseek
#define _tell tell
#define _filelength filelength

// File access constants
#ifndef F_OK
#define F_OK 0
#endif
#ifndef R_OK  
#define R_OK 4
#endif
#ifndef W_OK
#define W_OK 2
#endif
#ifndef X_OK
#define X_OK 1
#endif

// Open flags
#ifndef O_BINARY
#define O_BINARY 0
#endif
#ifndef O_TEXT
#define O_TEXT 0
#endif

// Function implementations (only if not already defined)
#ifndef LINUX_IO_H
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
#endif

#endif // IO_H_COMPAT