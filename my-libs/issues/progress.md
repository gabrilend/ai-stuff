# My-Libs Progress

Shared library infrastructure for reusable components across projects.

## Library Summary

| Library | Status | Issues |
|---------|--------|--------|
| threadpool | In Progress | 7/9 |
| zip | Complete | 1/1 |

---

## Threadpool Library (800)

**Location:** `/home/ritz/programming/ai-stuff/my-libs/threadpool/`

**Purpose:** General-purpose threading infrastructure extracted from world-edit-to-execute
render system. Provides modular components for thread pools, sync coordination, and
adaptive task distribution.

| ID | Name | Status | Dependencies |
|----|------|--------|--------------|
| 800 | Threadpool library extraction | In Progress | None |
| 800a | Core threadpool module | **Completed** | None |
| 800b | Sync module (watch list) | **Completed** | 800a |
| 800c | Updater module (self-evaluating) | **Completed** | 800a |
| 800d | Threadpool test suite | **Completed** | 800a, 800b, 800c, 800g |
| 800f | Windows support planning (platform layer) | **Completed** | 800a |
| 800g | Scheduler module (deferred tasks) | **Completed** | 800a |
| 800h | Hardening: races, lifecycle, sanitizer-clean tests | **Completed** | 800a-800d, 800g |
| 800i | Win32 backend for the platform layer | Pending (needs a Windows toolchain) | 800f, 800h |

### Dependency Graph

```
800 Threadpool Library Extraction
 │
 └──▶ 800a Core Module ──▶ 800b Sync Module
                       └──▶ 800c Updater Module
                       └──▶ 800f Windows Planning ──▶ 800i Win32 Backend
                       └──▶ 800g Scheduler Module
         │
         └──▶ 800d Test Suite ──▶ 800h Hardening
```

**Note:** Issue 800e (Render Migration) was moved to WETE as issue 802 since it's
specific to the world-edit-to-execute project.

### Key Features

- **Modular:** Core, sync, updater, and scheduler are independently usable
- **Self-evaluating updaters:** Helpers spawn/terminate based on measured load
- **Ring buffer task lists:** Efficient queuing with automatic relocation
- **Deferred task scheduling:** Absolute time-based scheduler with wake-on-add
- **Platform layer:** every OS call in `threadpool_platform.h` (POSIX now, Win32 planned in 800i)
- **Sanitizer-clean:** `make sanitize` runs every test under ThreadSanitizer and AddressSanitizer

### Consumer Projects

- world-edit-to-execute (Phase 8 consumer, origin of implementation)

---

## Zip Library (801)

**Location:** `/home/ritz/programming/ai-stuff/my-libs/zip/`

**Purpose:** a zip packer and a metered zip reader in plain Lua, running on
LuaJIT and Lua 5.3/5.4, so that rao-chat and rmail share one reader and
neither calls the zip programs.

| ID | Name | Status | Dependencies |
|----|------|--------|--------------|
| 801 | Zip library | **Completed** | None |

### Consumer Projects

- rao-chat (origin: issue 216e)
- rmail (#405)
