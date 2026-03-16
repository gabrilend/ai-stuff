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

- [ ] Not started
