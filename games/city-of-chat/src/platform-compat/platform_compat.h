#ifndef PLATFORM_COMPAT_H
#define PLATFORM_COMPAT_H

// Platform compatibility layer for City of Heroes Linux port
// This header provides Windows API compatibility for Linux builds

#ifdef __linux__
    #define LINUX 1
    #define _GNU_SOURCE 1
    
    // Prevent Windows headers from being included
    #define _IO_H_INCLUDED
    #define _DIRECT_H_INCLUDED  
    #define _CONIO_H_INCLUDED
    #define io_h
    #define direct_h
    #define conio_h
    
    // Include all Windows compatibility headers
    #include "windows_types.h"
    #include "io.h"
    #include "direct.h"
    #include "conio.h"
    #include "process.h"
    #include "intrin.h"
    #include "sal.h"
    #include "excpt.h"
    #include "superassert.h"
    
    // Windows types to POSIX mappings  
    #include <stdint.h>
    typedef int BOOL;
    typedef unsigned char BYTE;
    typedef unsigned short WORD;
    typedef unsigned long DWORD;
    typedef unsigned int UINT;
    typedef void* HANDLE;
    typedef char* LPSTR;
    typedef const char* LPCSTR;
    
    // Pre-define these to match the ones disabled in stdtypes.h
    typedef uint64_t U64;
    typedef int64_t S64;
    typedef volatile uint64_t VU64;
    typedef volatile int64_t VS64;
    
    // Also define U32 (should be in stdtypes.h but may not be available yet)
    #ifndef U32
    typedef unsigned int U32;
    #endif
    
    // CoH-specific types for parsing
    typedef U32 StructTypeField;
    typedef U32 StructFormatField;
    
    typedef struct ParseTable {
        char const* name;
        StructTypeField type;
        size_t storeoffset;
        intptr_t param;
        void* subtable;
        StructFormatField format;
        int minversion;
    } ParseTable;
    
    // Boolean constants
    #ifndef TRUE
    #define TRUE 1
    #endif
    #ifndef FALSE
    #define FALSE 0
    #endif
    
    // Windows calling conventions (no-op on Linux)
    #define __stdcall
    #define __cdecl
    #define WINAPI
    
    // Memory and string functions
    #include <string.h>
    #include <strings.h>
    #include <stdlib.h>
    #include <stdio.h>
    
    // Windows string function mappings
    #define stricmp strcasecmp
    #define strnicmp strncasecmp
    #define _stricmp strcasecmp
    #define _strnicmp strncasecmp
    
    // Windows file system function mappings
    #define _stat stat
    #define _findclose closedir
    
    // Create a compatible structure for _finddata_t
    struct _finddata_t {
        unsigned attrib;
        time_t time_create;
        time_t time_access; 
        time_t time_write;
        size_t size;
        char name[260];
    };
    
    #define _findfirst(pattern, data) opendir(".")  // Simplified
    #define _findnext(handle, data) readdir((DIR*)handle)
    
    // Define missing utility functions that UtilitiesLib expects
    static inline long opt_atol(const char *nptr) {
        return strtol(nptr, NULL, 10);
    }
    
    // Also provide unsigned char version to avoid casting warnings
    static inline long opt_atol_unsigned(const unsigned char *nptr) {
        return strtol((const char*)nptr, NULL, 10);
    }
    
    // Thread and synchronization (basic mapping)
    #include <pthread.h>
    #include <unistd.h>
    
    // Network compatibility
    #include <sys/socket.h>
    #include <netinet/in.h>
    #include <arpa/inet.h>
    
    // Disable Windows-specific pragmas
    #define __pragma(x)
    
    // SuperAssert compatibility - disable assertions to avoid Windows-specific functionality
    #define DISABLE_ASSERTIONS
    
    // Define stubs for any remaining assertion macros that might get through
    #define assert(exp) do { if (!(exp)) { fprintf(stderr, "Assert failed: %s in %s:%d\n", #exp, __FILE__, __LINE__); abort(); } } while(0)
    #define assertmsg(exp, msg) do { if (!(exp)) { fprintf(stderr, "Assert failed: %s (%s) in %s:%d\n", #exp, msg, __FILE__, __LINE__); abort(); } } while(0)
    #define assertmsgf(exp, msg, ...) do { if (!(exp)) { fprintf(stderr, "Assert failed: %s in %s:%d\n", #exp, __FILE__, __LINE__); abort(); } } while(0)
    
    // Path manipulation
    #include <libgen.h>
    #include <limits.h>
    #include <dirent.h>
    
    // Time functions
    #include <time.h>
    #include <sys/time.h>
    
#else
    // Windows includes remain as-is
    #include <io.h>
    #include <windows.h>
#endif

// Cross-platform utility macros
#ifdef __linux__
    #define PLATFORM_SLEEP(ms) usleep((ms) * 1000)
    #define PLATFORM_PATH_MAX PATH_MAX
#else
    #define PLATFORM_SLEEP(ms) Sleep(ms)
    #define PLATFORM_PATH_MAX MAX_PATH
#endif

#endif // PLATFORM_COMPAT_H