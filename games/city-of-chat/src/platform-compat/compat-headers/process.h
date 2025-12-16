#ifndef PROCESS_H_COMPAT
#define PROCESS_H_COMPAT

// Compatibility header for Windows process.h on Linux
// Provides POSIX equivalents for Windows process functions

#include <unistd.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <spawn.h>
#include <stdlib.h>

// Process function mappings
#define _getpid getpid
#define _exit _exit

// Process execution modes (for _spawn* functions)
#define _P_WAIT 0
#define _P_NOWAIT 1

// Spawn function implementations (basic mappings)
static inline int _spawnl(int mode, const char *path, const char *arg0, ...) {
    // Simplified implementation - would need full varargs handling
    return system(path);
}

static inline int _spawnv(int mode, const char *path, const char *const argv[]) {
    if (mode == _P_WAIT) {
        return system(path);
    }
    return fork();
}

// Thread functions (basic stubs)
static inline void _beginthread(void (*start_address)(void *), unsigned stack_size, void *arglist) {
    // Stub implementation
}

static inline unsigned long _beginthreadex(void *security, unsigned stack_size, 
    unsigned (__stdcall *start_address)(void *), void *arglist, 
    unsigned initflag, unsigned *thrdaddr) {
    // Stub implementation
    return 0;
}

#endif // PROCESS_H_COMPAT