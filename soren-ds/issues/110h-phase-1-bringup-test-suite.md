# 110h — phase-1 hardware bring-up test suite

## Current behavior

`kernel_main` runs the phase-1 bring-up steps sequentially and
panics on the first failure. Each iteration of "flash, observe,
fix, reflash" produces exactly one piece of new information —
the failure mode of whichever step is currently broken. The
trips between the developer's main machine, the lab laptop,
and the device are the slow part of the loop; the panic-on-
first-failure shape makes every trip carry as little new data
as it could.

## Intended behavior

Instead of a panic-on-first-failure sequence, `kernel_main`
hands off to a test runner that walks through a list of
independent bring-up tests, logs each one's name and return
code, and continues past failures rather than parking. The
list is small — every test is a phase-1 hardware bring-up
step we already know how to express as "function that returns
zero on success."

The suite runs the same list twice. The second iteration
distinguishes "step is reliably broken" from "step is broken
on a cold first try but works once something else has warmed
up." For controller bring-up code that resets the controller
on every entry, both iterations should produce identical
results; a difference between them is itself a useful signal
about timing or initialization order.

The test list at the time this issue lands:

- `sd_init` — SDMMC0 controller bring-up plus SD card
  identification sequence.
- `debug_log_init` — set up the SD-backed log ring buffer
  (idempotent; the `log_ready` guard makes the second call a
  no-op).
- `emmc_init` — SDHCI controller bring-up plus eMMC card
  identification sequence. The current piece of phase 1 that
  is actively failing.
- `sd_roundtrip` — write a known pattern to a safe SD LBA,
  read it back, compare. Confirms the SD block driver does
  what it claims at the data-path level, not just the
  init-sequence level. Depends on `sd_init` having passed in
  the same iteration.
- `emmc_read_block_0` — read the eMMC's MBR/GPT block.
  Confirms the eMMC block driver does what it claims. Depends
  on `emmc_init` having passed.
- `usb_ep0_bringup` — attempt the deferred USB endpoint-zero
  configuration from 109b. We expect this to fail with the
  same `depcmd_issue` hang the 109b reopen documents; running
  it inside the test suite (with the 500 ms wall-clock timeout
  wrapping its own polling loops) gives us a place to catch
  any change in behavior.

The runner logs through `debug_write`, which fans out to the
SD-backed log once `sd_init` and `debug_log_init` succeed.
Tests that run before that point still execute, just without
log narration; their results show up in the log on the second
iteration if the prerequisites have come up.

The LED at the end of the suite distinguishes three outcomes:

- All tests passed both iterations →
  `STAGE_BACKUP_COMPLETE` (top red + bottom amber).
- Any test failed in either iteration →
  `STAGE_PANIC_GENERIC` (top red, bottom dark) plus a slow
  amber heartbeat on the bottom so the developer can tell
  "test failed" from "kernel hung."
- Kernel hung mid-suite → no visible end-state change; the
  developer reads the log to see which test was last.

The backup run (`emmc_backup_to_sd`) is *not* part of the
suite. It takes minutes at the current boot clock and would
dominate the runtime. It comes back once the prerequisite
tests are passing, or as its own follow-up flash.

## What this is deliberately not

Not a unit test framework, not a regression harness for
later phases, not a continuous-integration loop. The suite
exists for the duration of phase-1 hardware bring-up and is
expected to be removed (or refactored into the eventual phase
demo) once the underlying controllers come up reliably.

The suite is deliberately small: every test is a single
function call to something else, every test is "the obvious
thing to run." Anything more elaborate than that risks
hiding a bug inside the test code itself.

## Suggested implementation steps

1. Pick an index for the new source file (one above the
   current highest in `src/`).
2. Forward-declare the existing init and block-IO functions.
3. Wrap each into a test that returns 0 on success and a
   distinct non-zero value on failure.
4. Express the test list as a constant array of
   `{ name, function }`.
5. The runner loops over the array twice, narrating each
   entry through `debug_write` and counting failures.
6. Final LED reflects pass/fail.
7. `kernel_main` calls the runner instead of the inline
   sequence; the existing panic-on-failure paths go away.

## Related documents

- `docs/015-led-diagnostic-codes.md` — interpret the final
  LED state.
- `docs/017-clocks-and-timers.md` — CRU registers the
  bring-up tests poke.

## Blocked by

108 (allocator), 110 (CDC-ACM and its debug_write fan-out).

## Blocks

Not in the strict sense — the suite is tooling. Loosely,
every later phase-1 issue that depends on the eMMC or USB
bring-up becomes easier to close once the suite is running.
