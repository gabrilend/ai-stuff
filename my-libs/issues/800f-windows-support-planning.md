# Issue 800f: Windows Support Planning

**Phase:** 8 (Infrastructure Libraries)
**Type:** Design Research
**Priority:** Low
**Dependencies:** 800a, 800b, 800c (library must exist first)
**Parent:** 800-threadpool-library-extraction.md

---

## Purpose

Document requirements and approach for adding Windows support to the threadpool
library. This is a planning document - actual implementation is future work.

## Current Behavior

Library uses POSIX threading primitives:
- `pthread_t` for thread handles
- `pthread_create()` / `pthread_join()` for lifecycle
- `pthread_spinlock_t` for sync watch list protection
- `<stdatomic.h>` for atomic operations (C11, cross-platform)

## Windows Equivalents

| POSIX | Windows | Notes |
|-------|---------|-------|
| `pthread_t` | `HANDLE` | Thread handle |
| `pthread_create()` | `CreateThread()` | Or `_beginthreadex()` for CRT safety |
| `pthread_join()` | `WaitForSingleObject()` | Wait for thread termination |
| `pthread_spinlock_t` | `CRITICAL_SECTION` | Or `SRWLock` for readers/writers |
| `sysconf(_SC_NPROCESSORS_ONLN)` | `GetSystemInfo()` | CPU count detection |
| `usleep()` | `Sleep()` | Millisecond sleep (less precise) |
| `clock_gettime(CLOCK_MONOTONIC)` | `QueryPerformanceCounter()` | High-res timing |

## Abstraction Strategy

### Option A: Preprocessor Conditionals

```c
#ifdef _WIN32
    #include <windows.h>
    typedef HANDLE tp_thread_t;
    #define tp_thread_create(t, fn, arg) /* ... */
#else
    #include <pthread.h>
    typedef pthread_t tp_thread_t;
    #define tp_thread_create(t, fn, arg) pthread_create(t, NULL, fn, arg)
#endif
```

**Pros:** Simple, no runtime overhead
**Cons:** Scattered conditionals, harder to maintain

### Option B: Platform Abstraction Layer

```c
/* threadpool_platform.h */
typedef struct tp_thread tp_thread_t;
typedef struct tp_spinlock tp_spinlock_t;

int tp_thread_create(tp_thread_t* t, void* (*fn)(void*), void* arg);
int tp_thread_join(tp_thread_t* t);
void tp_spinlock_init(tp_spinlock_t* lock);
void tp_spinlock_lock(tp_spinlock_t* lock);
void tp_spinlock_unlock(tp_spinlock_t* lock);
void tp_spinlock_destroy(tp_spinlock_t* lock);
uint64_t tp_get_timestamp_us(void);
int tp_get_cpu_count(void);
void tp_sleep_us(uint64_t microseconds);
```

**Pros:** Clean separation, easy to add new platforms
**Cons:** Extra indirection, more files

### Recommendation: Option B

The platform abstraction layer is cleaner and matches the modular design of the
library. Implementation files:

```
my-libs/threadpool/
├── platform/
│   ├── threadpool_platform.h   # Platform-agnostic API
│   ├── threadpool_posix.c      # POSIX implementation
│   └── threadpool_win32.c      # Windows implementation (future)
```

## Implementation Considerations

1. **Sleep precision:** Windows `Sleep()` is millisecond granularity. For
   microsecond precision, use `timeBeginPeriod(1)` + busy-wait hybrid, or
   accept reduced timing accuracy.

2. **Spinlock alternatives:** Windows `CRITICAL_SECTION` is not a true spinlock
   but performs well for short critical sections. `SRWLock` is lighter but
   requires Vista+.

3. **Thread-local storage:** If needed, `__thread` (GCC) vs `__declspec(thread)`
   (MSVC) vs C11 `_Thread_local`.

4. **Atomic operations:** C11 `<stdatomic.h>` works on both platforms with
   modern compilers. MSVC requires `/std:c11` or later.

## Acceptance Criteria (for future implementation)

- [ ] Platform abstraction layer defined
- [ ] POSIX implementation using new abstraction
- [ ] Windows implementation passes same tests as POSIX
- [ ] No POSIX-specific code outside platform layer
- [ ] Build system supports both platforms (CMake or separate Makefiles)

## Related Documents

- 800a-core-threadpool-module.md - core uses all primitives
- 800b-sync-module.md - uses spinlock
- Microsoft Docs: Synchronization Functions

## Notes

Windows support is explicitly deferred. The platform abstraction should be
designed now (in 800a-800c) even if only POSIX is implemented, to avoid
painful refactoring later. Use typedef wrappers from the start.

Priority is low because primary development environment is Linux and the
game engine targets POSIX-compatible systems initially.
