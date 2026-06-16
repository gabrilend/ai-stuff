# 110g — SD card debug log

## Current behavior

`debug_write` in `src/011-cdc-acm.c` sends text through the
USB CDC-ACM bulk-IN endpoint to a host computer attached over
USB-C. When no host is attached — which is the explicit posture
during phase 1 hardware tests, per the threat model the project
committed to during issue 101 — those writes silently drop.

The diagnostic narration `kernel_main` and the eMMC backup
operation both emit through `debug_write` therefore reaches no
one during the threat-model-conscious first boot. The only
observable signal is LED stage transitions, which collapse
every diagnostic into a handful of patterns and cannot tell us
*which sector* of the eMMC backup failed, *which DW MSHC
command* the SD card init choked on, or *which DWC3 register*
the USB bring-up never saw the expected value in.

The result is that if the backup hangs or panics, the
developer has no information beyond "LED was last at green-
only when I powered off."

## Intended behavior

A small persistent log buffer in DRAM accumulates every
`debug_write` call. The buffer is flushed periodically to a
reserved region of the SD card (starting at LBA
`0x4000000` — about 2 GB into the card, well above the eMMC
backup region from 110e and not in any region Anbernic's
bootloader or BootROM cares about).

The reserved region is large enough (16 MB = 32,768 blocks)
to hold the entire bring-up narration plus the backup loop's
progress messages with comfortable headroom.

After the SD card is pulled from the device, the developer
`dd`s the reserved region off the card on the lab laptop and
reads it as plain text — the exact bring-up sequence, the
exact error code, the exact sector that failed. Same threat
model as 110e: the device wrote bytes to a removable card,
the lab laptop reads those bytes through a raw `dd` (no mount,
no execution path), so no compromised firmware on the device
can affect anything on the lab laptop.

Concretely:

- `src/017-debug-log.c` exposes `debug_log_init` and gets
  called by `kernel_main` after `sd_init` succeeds. It picks a
  page from the page allocator as a ring buffer.
- `debug_write` in 011-cdc-acm.c is extended (or wrapped) to
  also append to the ring buffer when the buffer is ready.
- A flush function writes the buffer to the SD card region
  whenever the buffer is more than half full. The backup loop
  calls the flush periodically; the LED `STAGE_BACKUP_COMPLETE`
  transition does a final flush.
- A new `STAGE_LOG_FLUSH_FAILED` is *not* added — the log is
  best-effort diagnostic, and a failure to flush the log
  should never block forward progress or panic the kernel.

## Why this is needed in phase 1

The threat model rules out USB-C to any trusted machine until
the eMMC is overwritten. The eMMC overwrite requires verifying
the boot partition's LBA. That verification requires booting,
which requires diagnostic visibility into the boot, which is
not possible through USB without violating the threat model.
The SD card debug log is the only diagnostic channel available
under those constraints.

## Long-term plan

This file and the SD card region it consumes are a phase 1
expedient, not a long-term mechanism. Once the threading core
and the soramech runtime exist, the RAM transcript ring
described in `docs/012-soramech-runtime.md` and built in phase 3
issue `310-ram-transcript-ring.md` is the right home for "the
last N events leading up to a panic." That ring is kept in RAM
and dumped through CDC-ACM on panic — no SD wear, no fixed
region of removable media consumed for kernel logs.

When 310 lands, this file's functionality is folded into the
ring, the SD card region is freed, and `src/017-debug-log.c`
goes away. Issue 310 references this issue and tracks that
removal.

## Suggested implementation steps

1. Write `src/017-debug-log.c`. It owns:
   - A ring-buffer pointer (allocated from the page allocator
     during `debug_log_init`).
   - A write-position pointer.
   - A flush function that writes buffer contents to SD card
     blocks starting at LBA `0x4000000`.
2. Modify `debug_write` in `src/011-cdc-acm.c` to also append
   to the ring (when the ring is ready).
3. `kernel_main` calls `debug_log_init` after `sd_init`
   succeeds.
4. The eMMC backup loop calls the flush function every ~1000
   sectors (matches the existing progress narration cadence).
5. After `STAGE_BACKUP_COMPLETE` lights, do a final flush.

## Related documents

- `docs/015-led-diagnostic-codes.md` — the LED layer remains
  the panic-time fallback when even SD card writes fail.
- `notes/safety/000-bricking-and-recovery.md` — why writing to
  removable storage is the safest diagnostic medium during
  phase 1.

## Blocked by

110f (the SD writer this log depends on), 108 (page allocator
for the ring buffer).

## Blocks

The diagnostic visibility needed for boot test #1 to be
debuggable when it fails. Not a blocker if everything works
on first try, but the value-per-effort ratio of having
diagnostic visibility on the first attempt is high.
