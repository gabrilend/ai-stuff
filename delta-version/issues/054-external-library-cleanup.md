# Issue 054: External Library Cleanup

**Phase**: 0 - Tooling
**Status**: Complete
**Priority**: High
**Created**: 2026-02-24
**Completed**: 2026-02-24
**Related**: Issue 051f (Library Install Script Generation)

---

## Current Behavior

After cleanup, only 105 C/C++ files remain tracked - all legitimate project code. External libraries are gitignored and can be restored via install scripts or package managers.

### Summary of Changes

| Action | Files Removed | Libraries |
|--------|---------------|-----------|
| First pass | 21,256 | CoH source, toolchains, Sol2/effil |
| Second pass | 2,349 | libharu, luahpdf, pixellib, raylib, Lua source, Love2D, LuaSocket |
| **Total** | **23,605** | All external libraries |

### Remaining C/C++ (Legitimate Project Code)

| Location | Files | Type |
|----------|-------|------|
| adroit/src/ | 28 | Project code |
| games/city-of-chat/ | 20 | Project code |
| world-edit-to-execute/src/ | 18 | Project code |
| my-libs/threadpool/ | 13 | Project library |
| neocities-modernization/libs/vulkan-compute/ | 11 | Project library |
| console-demakes/src/ | 10 | Project code |
| Others | 5 | Project code |

---

## Intended Behavior

1. External libraries should be gitignored - **DONE**
2. Installation scripts should exist to restore them - **DONE** (for major ones)
3. Only actual project code should be tracked - **DONE**
4. Language statistics should reflect actual project languages (Lua, Bash, C) - **Pending GitHub reindex**

---

## Implementation Steps

### Completed

- [x] Updated .gitignore with patterns for all external libraries:
  - `games/city-of-chat/src/coh-source/`, `build/`, `libs/`
  - `console-demakes/tools/gba-toolchain/`, `rgbds/`
  - `libs/sol/`, `libs/lua/effil/`, `libs/lua/effil-jit/`
  - `**/libs/effil/`, `**/libs/effil-jit/`, `**/libs/native/effil/`
  - `libs/c/pixellib/`, `libs/c/raylib/`
  - `RPG-autobattler/libs/lua/`, `RPG-autobattler/libs/love2d/`
  - `words-pdf/libs/libharu-*/`, `words-pdf/libs/luahpdf/`
  - `words-pdf/backup-mvp/libs/libharu-*/`
  - `**/libs/luasocket/`
  - `*.AppImage`

- [x] Created installation scripts:
  - `games/city-of-chat/scripts/install-coh-source.sh`
  - `console-demakes/scripts/install-toolchain.sh`
  - `libs/scripts/install-effil.sh`
  - `neocities-modernization/scripts/install-deps.sh`
  - `continual-co-operation/scripts/install-deps.sh`

- [x] Removed from git index (`git rm --cached -r`):
  - CoH source and build artifacts (6,957 + 6,558 files)
  - GBA/GBC toolchains (5,885 + 1,856 files)
  - Sol2/effil (1,504 files)
  - PixelLib (36 files)
  - Raylib (959 files)
  - Lua source (80 files)
  - Love2D AppImage (1 file)
  - libharu + luahpdf (574 + 31 files)
  - LuaSocket (852 files)

---

## Libraries Now Gitignored

| Library | Restore Method |
|---------|----------------|
| City of Heroes source | `games/city-of-chat/scripts/install-coh-source.sh` |
| ARM GCC toolchain | `console-demakes/scripts/install-toolchain.sh` |
| RGBDS | `console-demakes/scripts/install-toolchain.sh` |
| Effil | `libs/scripts/install-effil.sh` or project `install-deps.sh` |
| Sol2 | Bundled with Effil (git submodule) |
| Lua 5.2 | `apt install lua5.2 liblua5.2-dev` |
| LuaJIT | `apt install luajit libluajit-5.1-dev` |
| libharu | `apt install libhpdf-dev` or build from source |
| LuaSocket | `luarocks install luasocket` |
| Raylib | `git clone https://github.com/raysan5/raylib.git` |
| PixelLib | Download from source |
| Love2D | Download from love2d.org |

---

## Acceptance Criteria

- [x] .gitignore updated with all external library patterns
- [x] Installation scripts exist for major dependencies
- [x] Only actual project code remains tracked
- [ ] GitHub language statistics updated (requires push + time)

---

## Notes

This cleanup reduced tracked C/C++ files from ~10,000 to 105 - all of which are legitimate project code. GitHub should now show Lua and Bash as primary languages after the next reindex.

---

## Metadata

- **Estimated Size**: Large
- **Actual Size**: 23,605 files removed
- **Risk**: Low (files still exist on disk, just untracked)
- **Blocks**: None
- **Blocked By**: None
