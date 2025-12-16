#ifndef _STDTYPES_H
#define _STDTYPES_H

// Turn this on to enable realtime memory leak detection
//#define ENABLE_LEAK_DETECTION

#ifdef __cplusplus
#    define C_DECLARATIONS_BEGIN    extern "C"{
#    define C_DECLARATIONS_END    }
#else
#    define C_DECLARATIONS_BEGIN
#    define C_DECLARATIONS_END
#endif

#include <stddef.h>
#include <stdarg.h>
#include <string.h>

//headers to make our secure CRT stuff work somewhat transparently
#include <ctype.h>

// Platform-specific includes
#ifdef LINUX
    #include "linux_io.h"       // Replace <io.h>
    #include <unistd.h>         // Replace <direct.h>
    // Skip <conio.h> - not available on Linux
#else
    #include <io.h>
    #include <direct.h>
    #include <conio.h>
#endif

#include <time.h>
#ifdef __cplusplus
#    include <cstdio>
#else
#    include <stdio.h>
#endif
#include <stdlib.h>

// Platform compatibility definitions
#ifdef LINUX
    // POSIX equivalents for Windows directory functions
    #include <sys/stat.h>
    #include <sys/types.h>
    #define _mkdir(path) mkdir(path, 0755)
    #define _rmdir rmdir
    #define _getcwd getcwd
    #define _chdir chdir
#endif

// Rest of the file remains the same...
// (We'll include the rest of the original stdtypes.h content here)

// Basic type definitions that might be needed
#ifndef LINUX
// These are usually defined in Windows headers
#else
// Define basic Windows types for Linux
typedef int BOOL;
typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef unsigned long DWORD;
typedef long LONG;
typedef unsigned long ULONG;
typedef void* HANDLE;
typedef char* LPSTR;
typedef const char* LPCSTR;

#ifndef TRUE
#define TRUE 1
#endif
#ifndef FALSE
#define FALSE 0
#endif

#endif

#endif // _STDTYPES_H