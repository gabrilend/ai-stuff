# Phase 4 progress — SD card, filesystem, compile pipeline

Phase 4 makes persistent storage and on-device authoring real. By
the end of the phase, the device can read and write files on the
SD card through six soramech boxes; the on-device editor can save
a box's source to disk; the compile pipeline can turn that source
into a loaded function pointer at a new generation; the
hot-swap mechanism can replace the running version of the box
with the new generation while a map that uses it keeps running.

The runtime from phase 3 is the consumer of all of this. The
filesystem boxes attach to its descriptor table. The compile
pipeline writes its artifacts to `tmp/compiled/<map>/<generation>/`
on the RAM-backed symlink and registers each new generation with
the descriptor table. The hot-swap is a single atomic store on
the descriptor's `fn` field.


## The engine beneath this phase changed

Phases 2 and 3 were rewritten against the ceramic design; the old
issues are in `issues/superseded/`, with a README explaining what
moved where. In this phase, 406, 407, 409, 410, 411, 412 still describe the older
engine and have not been converted yet. Read them knowing that the box
catalogue is generated from box sources rather than being a table
filesystem boxes are added to; rebuilding a box replaces each running
station's call pointer rather than swapping a shared descriptor, and
the old code is released by a per-core pass counter rather than by
reference counting.

A reference to an issue numbered 2xx or 3xx in those files points at
the superseded issue of that number, not at the one holding that
number today.

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
9. `409-compile-pipeline.md` — take a box's `src/*.c` and
   produce a loadable function pointer at a new generation.
10. `410-artifact-tree-and-reference-counts.md` — manage
    generations under `tmp/compiled/<map>/<generation>/`; track
    live references; reclaim dead generations.
11. `411-hot-swap-atomic-descriptor-update.md` — replace a
    box's `fn` pointer on its descriptor with release ordering
    while running tasks finish on the old generation under the
    reference count.
12. `412-phase-4-demo.md` — write a file, reboot, read it back;
    edit a box's source through a test harness, recompile,
    watch a running map pick up the new code at its next fire.

## Completed issues

None yet.

## Open issues

All of 401 through 412.

## Phase demo

`issues/completed/demos/phase-4/run.sh` will exist once the
phase closes. It builds and flashes the kernel image, kicks the
demo through its three movements (file round-trip across a
reboot; box source edit and hot-swap; reference-count proof that
the running app held the old generation while the new arrived).
The demo passes when every assertion holds and the running app's
visible behaviour does not regress through the swap.
