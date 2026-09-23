# effil-loader

Knows where the threading library (effil) lives and loads it. effil is a
compiled C library built outside this project, so its folder has to be added to
Lua's C search path by hand.

Two callers share it so they can never disagree about which file they mean:

- `src/flat-html-generator.lua` — stage 9 runs its page workers on effil.
- `scripts/preflight-gate` — tries loading it before a build starts (issue
  10-069), so a broken library stops the run in seconds instead of hours in.

## External functions

### `M.try_load(cpath_entry)`
- **cpath_entry**: optional string, a `"…/?.so"` search pattern to use instead
  of `M.CPATH_ENTRY`. Only tests pass one.
- **returns**: the effil module (table) on success; or `nil` and the loader's
  error message (string).
- Adds the search pattern to `package.cpath` once; calling it again does not
  stack duplicates.

## Data

### `M.CPATH_ENTRY`
String. The `?.so` pattern where the LuaJIT build of effil is compiled to.
