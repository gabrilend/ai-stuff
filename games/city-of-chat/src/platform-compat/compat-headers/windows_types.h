#ifndef WINDOWS_TYPES_H_COMPAT
#define WINDOWS_TYPES_H_COMPAT

// Compatibility header for Windows-specific data types on Linux
// Provides Linux equivalents for Windows types

#include <stdint.h>
#include <time.h>

// Windows integer types - only define if not already defined
#ifndef __int64_defined
#define __int64_defined
typedef int8_t __int8;
typedef int16_t __int16;
typedef int32_t __int32;
typedef int64_t __int64;
#endif

// Windows calling conventions (empty on Linux)
#define __stdcall
#define __cdecl
#define __fastcall
#define __declspec(x)

// Windows-specific modifiers
#define WINAPI
#define CALLBACK

// Additional type definitions for CoH compatibility
// Define these early to prevent stdtypes.h from defining them with Windows syntax
#ifndef U64_DEFINED  
#define U64_DEFINED
typedef uint64_t U64;
typedef int64_t S64;
typedef volatile uint64_t VU64;
typedef volatile int64_t VS64;

// Prevent stdtypes.h from redefining these by creating the typedef lines
#define SKIP_U64_TYPEDEF
#endif

// SAL annotation stubs for __notnull and others
#define __notnull
#define __pre
#define __post
#define __valid
#define __nullterminated
#define __deref
#define __checkReturn
#define __maybenull
#define __notvalid
#define __elem_readableTo(x)
#define __elem_writableTo(x)
#define __byte_readableTo(x)
#define __byte_writableTo(x)
#define __in_ecount(x)
#define __in_bcount(x)
#define __in_ecount_opt(x)
#define __in_bcount_opt(x)
#define __exceptthat
#define __null

// File finding structure stub (defined in platform_compat.h)
typedef struct _finddata_t _finddata32_t;

#endif // WINDOWS_TYPES_H_COMPAT