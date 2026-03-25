# Issue 101: Create Makefile Build System

## Current Behavior

No build system exists. Project cannot be compiled.

## Intended Behavior

A Makefile that:
- Compiles all C source files in src/
- Links against raylib, pthreads, and system libraries
- Produces executable at bin/physics-sim
- Supports DEBUG=1 flag for debug builds
- Provides clean and run targets

## Suggested Implementation Steps

1. Create Makefile in project root
2. Define CC, CFLAGS, LDFLAGS variables
3. Add Linux-specific library flags (-lGL -ldl -lrt -lX11)
4. Create wildcard rules for .c -> .o compilation
5. Create bin directory if needed
6. Add clean target to remove build artifacts
7. Add run target for convenience
8. Test with empty main.c file

## Related Documents

- [006-build-instructions.md](../docs/006-build-instructions.md)

## Status

- [x] Completed

## Implementation Notes

**Files Created:**
- Makefile (project root)
- src/001-main.c (minimal test stub)

**Implementation Steps Completed:**

1. Created Makefile with CC, CFLAGS, LDFLAGS variables
2. Added Linux-specific library flags (-lGL -ldl -lrt -lX11)
3. Implemented wildcard rules for .c -> .o compilation
4. Added bin/ directory creation in build target
5. Implemented clean target to remove build artifacts
6. Implemented run target for convenience
7. Tested with minimal main.c file

**Test Results:**
- `make` compiles successfully
- `make DEBUG=1` enables debug flags (-g -O0 -DDEBUG)
- `make clean` removes object files and binary
- `make run` executes the binary
- Binary runs and exits cleanly

**Current Behavior:**
Build system fully functional. Can compile all .c files in src/ and link
against raylib, pthreads, and system libraries.
