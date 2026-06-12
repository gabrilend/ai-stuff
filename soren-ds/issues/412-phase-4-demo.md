# 412 — Phase 4 demo

## Current behavior

Issues 401 through 411 produce a working filesystem, the
persistence convention is wired, and the compile pipeline plus
hot-swap can replace a running box's function pointer under a
live reference count. Phase 4 needs a demo that exercises every
piece end to end.

## Intended behavior

The demo has three movements, scripted in
`issues/completed/demos/phase-4/run.sh`:

### 1. File round-trip across reboot

The kernel writes a known byte sequence to
`/test/round-trip.bin` through `write-path`. The kernel then
issues a software reboot. After the reboot, the kernel reads
the file back through `read-path` and asserts the bytes match.
This proves the FAT layer correctly persists data to the
physical SD card and that the temp-and-rename pattern in
`write-path` survives a fresh boot.

### 2. Box source edit and hot-swap

The kernel statically embeds a tiny map with one box whose
function returns a constant integer. The map is running and
emitting that integer through `debug-write` once per second.
The demo:

- Writes new source for the box to
  `/programs/swap-demo/src/the-box.c`. The new source returns a
  different constant.
- Invokes the compile pipeline on the new source.
- Watches the running map. Asserts the box's output integer
  changes from the old constant to the new constant at the
  next fire after the hot-swap.

This proves the compile pipeline, the artifact tree, and the
atomic descriptor update all work as a system.

### 3. Reference-count proof

A long-running task is started against the old generation
deliberately — the test harness holds an extra reference. The
demo then issues another hot-swap. The new generation takes
over for new fires, but the old generation's reference count
stays at one. The test harness asserts:

- The old generation's directory under `tmp/compiled/` still
  exists.
- The artifact sweep does not reclaim it.
- After the test harness releases its reference, the next
  sweep pass reclaims the old generation and removes its
  directory.

The script asserts each movement's expected state and reports
pass or fail.

## Suggested implementation steps

1. The round-trip portion of the script — write, reboot,
   read, assert.
2. The swap-demo embedded map plus the box source on the SD
   card.
3. The reference-count test harness — a small helper that
   `artifact_acquire`s and releases on signal.
4. The shell script wrapping build / flash / orchestration.

## Related documents

- `docs/002-roadmap.md` — phase 4 demo description.
- `docs/011-filesystem.md`.
- `docs/012-soramech-runtime.md`.

## Blocked by

All of 401 through 411.

## Closes

Phase 4.
