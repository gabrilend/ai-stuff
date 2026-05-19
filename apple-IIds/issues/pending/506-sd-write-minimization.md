---
name: SD-card write minimization
phase: 5
status: pending
blockedBy: [301]
---

# 506 — SD-card write minimization

Reduce write traffic to the microSD card to extend its lifespan and
avoid latency spikes. Coalesce writes, prefer RAM-backed scratch,
flush only when necessary.

## current behavior

The broker and the emulators write to the SD card freely. Without
intervention, GS/OS will write the Finder's desktop database, scrap
file, preferences, etc., on every minor change. Plus the broker's
logs, audit trail, and shared-volume writes. The SD card is taking
the brunt.

## intended behavior

- The broker maintains a **write cache** in RAM. Writes to the shared
  volume are buffered there until a flush condition triggers.
- Flush conditions:
  - Time-based: every 60 seconds if anything is dirty.
  - Size-based: when the dirty buffer exceeds N MB.
  - Event-based: on `File:Close` for any file (so closed files
    are committed promptly).
  - Sleep-based: on Hall switch close (issue 505), flush
    immediately so wake doesn't lose data.
  - Explicit: a "save now" command via settings UI.
- The broker's own logs (`tmp/broker.log`, audit log) live in
  `tmp/` which is RAM-backed (already symlinked to `/tmp/`). They
  do not touch SD card. On clean shutdown, the broker copies the
  audit log to the SD card if the user has enabled audit-log
  persistence (off by default).
- GS/OS's most frequent writes (informed by issue
  `pending/iigs-write-frequency-analysis.md`'s report) are
  intercepted in the broker's File Manager layer and either
  cached, batched, or eliminated.

## suggested implementation steps

1. Wait for `pending/iigs-write-frequency-analysis.md` to produce
   its report. It identifies which routines write most often and
   what's removable.
2. Implement the write cache in `src/broker/write-cache.lua`:
   in-memory buffer keyed by path, with dirty bits and timestamps.
3. Add the flush-condition logic.
4. Wire the broker's File Manager intercepts (from issue 301) to
   write into the cache instead of straight to disk.
5. Add the Hall-switch flush hook.
6. Test under load: type continuously for 10 minutes, observe how
   many SD writes occurred. Without the cache: probably hundreds.
   With the cache: probably under ten.
7. Measure write traffic with `iostat` or `/proc/diskstats` before
   and after.

## related documents

- `docs/001-architecture-overview.md` — operational constraints
- `issues/pending/iigs-write-frequency-analysis.md` — the upstream
  research that informs which writes to intercept
- `issues/301-shared-backing-filesystem.md` — provides the FS layer
- `issues/505-suspend-to-ram.md` — the flush-on-sleep hook

## known design questions

- What if the device loses power suddenly (battery dies,
  unintentional reset)? Up to 60 seconds of unsaved work may be
  lost. Acceptable; document this explicitly. A future improvement
  is a UPS-like brown-out detection that triggers an immediate
  flush, but that's hardware-dependent.
- Should the user be able to see the dirty buffer? Yes, via a
  small status indicator (e.g., a tiny "saving in N seconds" dot
  on the status strip). Optional.

## notes

- This is one of the issues that gets *more* important after the
  bare-metal port (phase 11). At that point we're managing the SD
  card directly without Linux's page cache helping us out. Patterns
  established here transfer.
