# Issue 105 - Create Local Dependency Build Script

## Current Behavior

The project relies on system-wide installation of raylib. This creates
inconsistencies across development environments and makes the build
less reproducible. The build instructions in `docs/006-build-instructions.md`
direct users to install raylib via package manager or manually.

## Intended Behavior

A `scripts/build-deps.sh` script should:
1. Download raylib source code from the official repository
2. Build raylib locally in the `libs/` directory
3. Place built libraries and headers in a predictable location
4. Allow the Makefile to reference local raylib instead of system-wide

The local dependency approach provides:
- Reproducible builds across environments
- Version pinning for stability
- Independence from system package managers
- Easier CI/CD integration

## Suggested Implementation Steps

1. Create `scripts/build-deps.sh` with:
   - Hard-coded DIR variable at top (per project conventions)
   - Option to override DIR via argument
   - Clone raylib to `libs/raylib`
   - Build raylib in place
   - Verify build success

2. Update Makefile to support local raylib:
   - Add RAYLIB_PATH variable
   - Update CFLAGS to include local headers
   - Update LDFLAGS to link local library
   - Fall back to system raylib if local not found (optional)

## Related Files

- `scripts/compile` - existing compile script
- `Makefile` - needs updating after script is complete
- `docs/006-build-instructions.md` - needs updating after script is complete

## Dependencies

- git (for cloning raylib)
- make, gcc (for building raylib)
- OpenGL development headers (system requirement)

## Notes

- Raylib repository: https://github.com/raysan5/raylib
- Building raylib: `make PLATFORM=PLATFORM_DESKTOP` in src/ directory
- Consider pinning to a specific raylib version/tag for stability

## Implementation Log

### scripts/build-deps.sh Created
- Hard-coded DIR variable with argument override support
- Downloads raylib via git clone with --depth 1
- Pins to raylib version 5.0 for stability
- Builds static library (libraylib.a) in libs/raylib/src/
- Supports --clean flag for fresh rebuilds
- Verifies build artifacts exist before reporting success
- Uses vimfolds for function organization

### Makefile Updated
- Added RAYLIB_PATH variable pointing to ./libs/raylib/src
- Updated CFLAGS to include -I$(RAYLIB_PATH) for headers
- Updated LDFLAGS to link $(RAYLIB_PATH)/libraylib.a directly
- Removed -lraylib system library dependency
- Added comment noting raylib is built locally

### Build Tested
- Clean compilation with no errors
- Successfully links against local libraylib.a
- Binary runs correctly
