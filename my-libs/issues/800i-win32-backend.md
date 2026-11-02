# Issue 800i: Win32 Backend for the Platform Layer

**Phase:** 8 (Infrastructure Libraries)
**Type:** Implementation
**Priority:** Low
**Dependencies:** 800f (platform layer), 800h (hardening)
**Parent:** 800-threadpool-library-extraction.md
**Blocked on:** a Windows toolchain to build and run the tests (MinGW-w64
cross compiler plus Wine, or a Windows machine with MSVC or MinGW)

---

## Current Behavior

Every OS call the threadpool makes is in `src/threadpool_platform.h`, which
has a POSIX backend only. Building with `_WIN32` defined stops at an
`#error` that points here.

## Intended Behavior

A second section of `threadpool_platform.h`, under `#if defined(_WIN32)`,
gives the same `tp_*` names on Windows, and the unchanged test suite passes
there.

| Platform layer | Win32 |
|---|---|
| `tp_thread_t` | `HANDLE` |
| `tp_thread_create(t, fn, arg)` | `_beginthreadex` with a small heap-allocated trampoline `{fn, arg}` that calls `fn(arg)` and frees itself (the thread signature differs: `unsigned __stdcall (void*)`) |
| `tp_thread_join(t)` | `WaitForSingleObject(t, INFINITE)` then `CloseHandle(t)` |
| `tp_mutex_t` | `CRITICAL_SECTION` (`InitializeCriticalSection`, `Enter...`, `Leave...`, `Delete...`) |
| `tp_cond_t` | `CONDITION_VARIABLE` (`InitializeConditionVariable`, `SleepConditionVariableCS`, `WakeConditionVariable`, `WakeAllConditionVariable`; no destroy needed) |
| `tp_cond_timedwait_us(c, m, us)` | `SleepConditionVariableCS(c, m, ms)` with `ms` rounded **up** from `us` (so a short wait is never zero), clamped below `INFINITE`; returns false when `GetLastError() == ERROR_TIMEOUT` |
| `tp_spinlock_t` | unchanged (C11 `atomic_flag`); `SwitchToThread()` in place of `sched_yield()` |
| `tp_time_us()` | `QueryPerformanceCounter` / `QueryPerformanceFrequency`, scaled without overflow (split whole seconds and remainder) |
| `tp_sleep_us(us)` | `Sleep(ms)` rounded up; note 1ms granularity at best, ~15.6ms without `timeBeginPeriod(1)` |
| `tp_cpu_count()` | `GetSystemInfo` → `dwNumberOfProcessors` |

## Suggested Implementation Steps

1. Get a toolchain: `x86_64-w64-mingw32-gcc` and `wine` on Linux is enough to
   build and run the tests from this repo.
2. Write the `_WIN32` section of `threadpool_platform.h` per the table; keep
   the POSIX section untouched.
3. Check C11 atomics: MinGW-w64 gcc has `<stdatomic.h>`; MSVC needs
   `/std:c11 /experimental:c11atomics` (VS 2022 17.5+). Note this in README.
4. `##__VA_ARGS__` in the log macros: MSVC accepts it; confirm.
5. Tests: `test_common.h` already uses only `tp_time_us`/`tp_sleep_us`.
   Timing tests use generous bounds, but `test_scheduler_sleep_ticks_sleeps`
   asserts at least 45ms of a 50ms sleep; with `Sleep()` rounding up that
   holds.
6. Makefile: a `win` target that builds with `CC=x86_64-w64-mingw32-gcc`,
   drops `-pthread`, adds `.exe`, and runs the tests under `wine`.
7. Run `make check-portable` (must still pass) and the full suite on Windows.

## Acceptance Criteria

- [ ] Win32 section of `threadpool_platform.h` provides every `tp_*` name
- [ ] All 43 tests pass on Windows (or under Wine) with MinGW-w64
- [ ] Builds with MSVC (documented flags)
- [ ] `make check-portable` still passes; POSIX results unchanged
- [ ] README platform line says Windows

## Notes

Decided in 800f: relative timeouts in the platform API exist precisely so
this backend is a direct call to `SleepConditionVariableCS`.
