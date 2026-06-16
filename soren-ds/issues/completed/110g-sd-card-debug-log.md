# 110g — SD card debug log

## Current behavior

`src/017-debug-log.c` owns a 4 KB ring buffer in DRAM, set up
by `debug_log_init` after the microSD card is brought up. The
ring buffer's page comes from the page allocator (108).

`debug_write` in `src/011-cdc-acm.c` is extended at its top to
call `debug_log_append` before the existing CDC-ACM transfer
logic. The append copies bytes into the ring buffer, and when
the buffer crosses 75% full it triggers a flush — eight blocks
(4 KB) written out to the SD card starting at LBA `0x4000000`,
the next write tracked through a static counter so successive
flushes append rather than overwrite. When the counter reaches
the region's end (`LOG_SD_REGION_SIZE` = 32,768 blocks =
16 MB), it wraps back to the start.

`kernel_main` calls `debug_log_init` after `sd_init` succeeds.
The eMMC-backup loop's existing `debug_write` calls now
populate the SD log automatically — no explicit flush calls
from the backup loop are needed because the threshold triggers
within the per-sector narration. A final `debug_log_flush`
call after the backup completes (or on panic) ensures the
buffer's tail bytes land on the card before the
`STAGE_BACKUP_COMPLETE` signal lights up.

After the SD card is pulled from the device, the developer
`dd`s the reserved region off the card on the lab laptop:

```
sudo dd if=/dev/sdX bs=512 skip=67108864 count=32768 \
        of=~/boot-log.bin status=progress
strings ~/boot-log.bin | head -200
```

The result is plain-text bring-up narration: every `[emmc]`,
`[sdmmc]`, `[backup]`, `[boot-image]` message, in order, the
exact sector that failed if anything did, the exact return code
the controller returned.

The closing condition on real hardware is implicit: if the
first hardware run captures a readable log from the SD card,
this issue closes. The implementation has not been observed
working because we have not yet booted.

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
