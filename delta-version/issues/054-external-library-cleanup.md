# Issue 054: External Library Cleanup

**Phase**: 0 - Tooling
**Status**: In Progress
**Priority**: High
**Created**: 2026-02-24
**Related**: Issue 051f (Library Install Script Generation)

---

## Current Behavior

The repository contains 51,726 C/C++ files on disk, with 9,818 tracked in git (32% of all tracked files). Most of these are external libraries and toolchains that:

1. Inflate repository size unnecessarily
2. Skew GitHub language statistics (shows "mostly C/C++" instead of Lua/Bash)
3. Should be installed via scripts rather than committed
4. Include documentation (1,294 Roff/man pages) that doesn't belong in source control

### Libraries Currently Tracked

| Location | Files | Size | Type |
|----------|-------|------|------|
| games/city-of-chat/src/coh-source/ | ~5,500 | 228MB | City of Heroes source + 3rdparty |
| games/city-of-chat/build/ | varies | 481MB | Build artifacts (OpenSSL, zlib) |
| games/city-of-chat/libs/ | 135+ | 36MB | Compiled OpenSSL/zlib |
| console-demakes/tools/gba-toolchain/ | ~1,200 | 869MB | GCC ARM cross-compiler |
| console-demakes/tools/rgbds/ | varies | ~10MB | RGBDS assembler + man pages |
| libs/lua/effil/ (4 copies) | 272 | ~2MB | Sol2 C++ Lua bindings |
| RPG-autobattler/libs/lua/ | 59 | ~1MB | Lua 5.2 source |
| words-pdf/libs/libharu/ | 58 | ~2MB | LibHaru PDF library |

### Already Gitignored (Correct)

| Location | Size | Notes |
|----------|------|-------|
| games/wow-chat-2/ | 17GB | Separate .git repo |
| games/gameboy-color-rpg/libs/emsdk/ | 1.7GB | Emscripten SDK |

---

## Intended Behavior

1. External libraries should be gitignored
2. Installation scripts should exist to restore them
3. Only actual project code should be tracked
4. Language statistics should reflect actual project languages (Lua, Bash, C)

---

## Implementation Steps

### Completed

- [x] Updated .gitignore with new patterns:
  - `games/city-of-chat/src/coh-source/`
  - `games/city-of-chat/build/`
  - `games/city-of-chat/libs/`
  - `console-demakes/tools/gba-toolchain/`
  - `console-demakes/tools/rgbds/`

- [x] Created installation scripts:
  - [x] `games/city-of-chat/scripts/install-coh-source.sh` - Downloads/extracts CoH source
  - [x] `games/city-of-chat/scripts/build_dependencies.sh` - Already existed, builds zlib/OpenSSL/Boost/PostgreSQL
  - [x] `console-demakes/scripts/install-toolchain.sh` - Downloads ARM GCC and RGBDS

### In Progress

### Pending

- [ ] Remove tracked files from git history (optional, preserves history)
- [ ] Or: Remove from index only (`git rm --cached -r`)
- [ ] Deduplicate Sol2/effil copies (4 identical copies)
- [ ] Evaluate whether Lua source should be vendored or installed
- [ ] Evaluate whether libharu should be vendored or installed
- [ ] Update documentation to reference install scripts

---

## Recommendations by Project

### games/city-of-chat/

**Action**: Gitignore + install script

The City of Heroes source code is a 228MB external dependency. It should be:
1. Downloaded from its source repository
2. Built using the existing build scripts
3. Not committed to this repository

```bash
# Proposed: games/city-of-chat/scripts/install-deps.sh
# Downloads CoH source, builds OpenSSL, zlib
```

### console-demakes/

**Action**: Gitignore + install script

The GCC ARM toolchain (869MB) should be:
1. Downloaded from ARM's releases
2. Extracted to tools/
3. Not committed

```bash
# Proposed: console-demakes/scripts/install-toolchain.sh
# Downloads gcc-arm-none-eabi and rgbds
```

### Sol2/effil duplicates

**Action**: Consolidate to shared library

Currently 4 identical copies exist:
- libs/lua/effil/libs/sol/
- libs/lua/effil-jit/libs/sol/
- continual-co-operation/libs/effil/libs/sol/
- continual-co-operation/libs/effil-jit/libs/sol/

Should be consolidated to a single `libs/sol2/` with symlinks.

### RPG-autobattler/libs/lua/ and words-pdf/libs/libharu/

**Action**: Evaluate - likely keep vendored

Small libraries (~1-2MB each) that are:
- Commonly vendored in projects
- Provide reproducibility
- Don't significantly impact repo size

Decision: **Keep for now**, but consider luarocks/system packages for Lua.

---

## Acceptance Criteria

- [ ] .gitignore updated with all external library patterns
- [ ] Installation scripts exist for city-of-chat and console-demakes
- [ ] README or INSTALL.md documents how to set up dependencies
- [ ] GitHub language statistics show Lua/Bash as primary languages
- [ ] Repository clone size reduced by ~1.5GB

---

## Notes

This cleanup supports the project's stated goal of using "C, Lua, and Bash" as primary languages. The C/C++ currently tracked is almost entirely from external game sources and cross-compilation toolchains, not from project code.

---

## Metadata

- **Estimated Size**: Large (multiple scripts + history cleanup)
- **Risk**: Medium (removing tracked files requires care)
- **Blocks**: None
- **Blocked By**: None
