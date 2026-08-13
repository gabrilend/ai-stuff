# Phase 4 progress — SD card, filesystem, compile pipeline

Phase 4 makes persistent storage and on-device authoring real. By the
end of the phase, the device can read and write files on the SD card
through six boxes; the editor can save a box's source to the card; the
device can run the generator and a compiler over that source and add
the result to its catalogue; and a station running the new box can be
placed and wired into a program that is already running, without the
device restarting and without anything else losing what it held.

The runtime from phase 3 is the consumer of all of this. The
filesystem boxes are ordinary box sources the generator catalogues
because of where they live. The compile pipeline runs that same
generator on the device, compiles what it emits into a page, and adds
a row to a catalogue that grows by paging rather than by moving what
is already there.

**A box is not swapped in underneath a running station.** A station's
ports were sized to its box's parameter widths and may be holding
values right now, so its box cannot change. Replacing one is a new
station, the arrows moved to it in a batch, and the old station left
with no source — the same inert state that parks a program and that a
failing box uses to take itself out of service. The old code is freed
once no core can still be inside it, by the same per-core counters
that reclaim an old set of arrows.


## The story of the phase

1. `401-sd-card-block-driver.md` — speak the SDHC/SDXC command
   protocol; read and write blocks.
2. `402-fat-partition-reader.md` — parse the MBR and the FAT
   boot parameter block; locate the FAT and the data area.
3. `403-fat-directory-walker.md` — open the root directory and
   walk subdirectories.
4. `404-fat-cluster-chain-follower.md` — read and write file
   contents by following the FAT chain.
5. `405-path-resolution-and-symlinks.md` — turn a path string
   into a directory entry; follow the magic-header symlinks
   from the filesystem doc.
6. `406-read-write-path-boxes.md` — `read-path` and
   `write-path`. The two box kinds that move bytes between the
   runtime and disk.
7. `407-other-filesystem-boxes.md` — `list-directory`,
   `delete-path`, `path-exists`, `make-symlink`. The four
   smaller box kinds.
8. `408-persistence-convention.md` — the `/settings/` tree, the
   boot-time restore that reads it, the apps that write to it.
9. `409-compile-pipeline.md` — run the generator and a compiler over
   a box's source on the device, and add a row to a catalogue that
   grows by paging.
10. `410-code-that-outlives-its-boxes.md` — retire, sweep, free, on
    the same per-core counters that reclaim an old set of arrows. No
    reference counts and no generations.
11. `411-replacing-a-box-in-a-running-program.md` — a new station,
    the arrows moved in a batch, the old station left with no source.
    A station's box cannot change, because its ports were sized to it.
12. `412-phase-4-demo.md` — write a file, reboot, read it back; write
    a box's source through a test harness, compile it, place it, move
    the arrows, watch the output change at the first run afterwards.

## Completed issues

None yet.

## Open issues

All of 401 through 412.

## Phase demo

`issues/completed/demos/phase-4/run.sh` will exist once the
phase closes. It builds and flashes the kernel image, kicks the
demo through its three movements (a file round-trip across a reboot; a
box written on the device and put to work; and old code being freed
only once no core can be inside it, while a placed box's code is never
freed and the sweep says why). It passes when every assertion holds and
the running program's visible behaviour changes exactly once, at the
first run after the arrows move.
