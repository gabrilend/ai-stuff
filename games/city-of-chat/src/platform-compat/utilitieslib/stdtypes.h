#ifndef LINUX_STDTYPES_H
#define LINUX_STDTYPES_H

// Linux-compatible wrapper for UtilitiesLib stdtypes.h
// This file replaces the original to resolve Windows-specific type conflicts

// First include our Linux compatibility types
#include "../compat-headers/windows_types.h"

// Include the patched stdtypes.h that has the problematic lines disabled
#include "../stdtypes.h"

// Now define the types that were disabled in the original file
#ifndef U64
typedef uint64_t U64;
typedef int64_t S64;
typedef volatile uint64_t VU64;
typedef volatile int64_t VS64;
#endif

#endif // LINUX_STDTYPES_H