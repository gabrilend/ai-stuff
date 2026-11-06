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
station, the arrows moved to it in a batch, and then the old station
**removed** — its place handed back for whatever is added next. The old
code is freed once no core can still be inside it, by the same per-core
counters that reclaim an old set of arrows.

That last step used to leave the old station standing with no source
forever, because a station could not be removed. It can (207, and the
reasoning is in `phase-2-progress.md`), and on this phase it is the
difference between a device that accumulates one dead station per save and
one that does not. The inert no-source state still exists for the two things
that want a station to stop running and stay: parking a program, and a
failing box taking itself out of service. The editor defers the removal
until the person is done looking (804), because putting the arrows back is
how somebody undoes a save.

**And a box compiled here gets a real address.** A station line names a
file and a function, so a box compiled on the device is addressed by the
file its source was saved to — which it has, because the source arrived by
being written to the card. That is what lets a program assembled at the
touchscreen be **written back out as something that can be built again**:
a map file plus a directory of the C of every box it places, the ones from
the kernel image and the ones from somebody's fingers written out
identically. Without it, a program containing a device-written box could be
described and never rebuilt.


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
13. `413-append-path.md` — a file larger than one 4096-byte value,
    built from several appends, each whole or not at all. Filed when
    the value's cap was kept rather than grown.

## Completed issues

Built as portable C in `src/system/` and proven on the laptop twin
against cards a laptop's tools would make. Counts:
`progress-dashboard.lua <project> -m`.

- **402** the partition table and the FAT32 boot block, at block zero or
  with no partition table at all; FAT16, exFAT and boot blocks whose
  numbers do not add up refused with a line saying why.
- **403** directories walked with long names assembled; entries added,
  updated in place, removed; directories made. Every entry gets its own
  short name however crowded the directory.
- **404** the whole table in memory, chains followed and freed, a write
  always a new chain; flushed to every copy with FSInfo kept current. A
  damaged chain is an end, never a step outside the table.
- **405** paths from the root, `.` and `..`, any case; the device's
  symlinks followed at every component, relative or absolute, with loops
  ending in an error. The one mounted card and its lock, and every
  whole-file operation the boxes of 406 and 407 will call: read a slice,
  replace atomically (making directories on the way), list, delete, ask,
  link, make a directory.
- **406** `read_path`, `read_slice` and `write_path`, passing `struct
  path` and `struct file_bytes`; a read wired into a write is a copy.
- **407** `list_directory` (in a pinned layout, the names that do not fit
  counted), `delete_path`, `path_exists`, `make_symlink`; and `text_path`
  and `path_join` to build a path from text.
- **413** `append_path`: the value's bytes added to the end of a file,
  filling the last cluster's spare room, then new clusters linked on, then
  the size; interrupted, the file is its old self and the stray clusters
  are let go by the next append. A file of any size is several appends.

402–404 live in `src/system/077-fat.c`, 405 in `src/system/078-files.c`,
the boxes of 406, 407 and 413 in `src/boxes/082-files.c`.
Tests: `twin/tests/079` (118 checks, on one-sector and eight-sector
clusters; `fsck.fat` checks every card it writes and a `mkfs.fat` card
gets the writing checks, where the laptop has those tools) and `081` (56
checks, four threads at once among them) and `083` (37 checks, every box
placed in a map and fed through its doors) and `092` (44 checks: appends
on both cluster sizes, a full card, a card left mid-append, two threads on
one file, a copy in 4096-byte slices) and `093` (22 checks: replacing,
appending and making a file, each with the card pulled out after every
block it writes, old or new and never torn), all on cards
`twin/tests/080-card-image.h` lays out the way a laptop does, with phases
2 and 3's still passing.

## Open issues

- **401** — the card's block calls exist on both sides of the platform
  seam (the twin's disk image, the device's phase-1 driver from 110f);
  the device side is unverified.
- **408** through **412**.

## Phase demo

`issues/completed/demos/phase-4/run.sh` will exist once the
phase closes. It builds and flashes the kernel image, kicks the
demo through its three movements (a file round-trip across a reboot; a
box written on the device and put to work; and old code being freed
only once no core can be inside it, while a placed box's code is never
freed and the sweep says why). It passes when every assertion holds and
the running program's visible behaviour changes exactly once, at the
first run after the arrows move.
