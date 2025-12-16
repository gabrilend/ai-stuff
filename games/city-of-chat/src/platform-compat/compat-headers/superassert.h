#ifndef SUPERASSERT_COMPAT_H
#define SUPERASSERT_COMPAT_H

// Compatibility layer for SuperAssert functionality on Linux
// This provides stubs for Windows-specific assertion system

#include <stdio.h>
#include <stdlib.h>

// Global NULL pointer for crash functionality (Linux stub)
extern int *g_NULLPTR;

// Force crash macro (Linux safe version)
#define FORCE_CRASH abort()

// Stub implementations for superassert functions
static inline int superassert(const char* expr, const char *errormsg, const char* filename, unsigned lineno) {
    fprintf(stderr, "ASSERT FAILED: %s\n", expr);
    fprintf(stderr, "  File: %s, Line: %u\n", filename, lineno);
    if (errormsg) {
        fprintf(stderr, "  Message: %s\n", errormsg);
    }
    return 1; // Trigger crash
}

static inline int superassertf(const char* expr, const char* errormsg_fmt, const char* filename, unsigned lineno, ...) {
    fprintf(stderr, "ASSERT FAILED: %s\n", expr);
    fprintf(stderr, "  File: %s, Line: %u\n", filename, lineno);
    if (errormsg_fmt) {
        fprintf(stderr, "  Message: %s\n", errormsg_fmt);
    }
    return 1; // Trigger crash
}

#endif // SUPERASSERT_COMPAT_H