# Filesystem

The device has an SD card and nothing else for persistent
storage. This doc describes what the kernel needs from that card,
what it pointedly does not need, and the box abstraction the
runtime exposes above it.

## What the hardware demands

An SD card stores bytes in fixed-size blocks, addressed by block
number. The card's controller takes block-read and block-write
commands over a small command protocol and reports completion. It
has no notion of files, directories, names, or anything richer
than "give me block N" and "here are bytes, put them at block M."

If the kernel did nothing on top of that, the card would still be
useful — we could pick block ranges, write to them, and read them
back. But a card formatted as raw blocks cannot be read by a
laptop without our cooperation, and one of the project's goals is
that the user can pull the card out, stick it in a computer, and
see their drawings and their programs as ordinary files.

That goal is what forces a filesystem. Specifically: a FAT-family
filesystem. FAT32 in particular is what consumer SD cards come
formatted as, what every desktop operating system reads and
writes without question, and what the user gets if they reformat
the card on a laptop without paying attention. We meet the card
where it is.

## What the hardware does *not* demand

A long list of things that desktop and server operating systems
build on top of their filesystems, none of which the user of this
device asks for:

- **Permissions.** One human holds the device; there is no
  "other" to defend the user's files from. Every file is the
  user's. No user ID, no group ID, no `chmod`.
- **Hard links, symlinks.** A file is a name and the bytes at
  that name. The kernel never resolves indirection.
- **Mounts.** There is one filesystem and it lives on the SD
  card. No tree of mount points, no `/mnt/`, no removable-media
  abstraction. If the SD card is gone, the filesystem is gone;
  the apps cope.
- **Journaling.** FAT doesn't journal. We accept the consequence:
  a power loss mid-write can corrupt the file being written. The
  apps that care (the editor saving documents, the painter
  saving drawings) write to a temporary path and rename on top
  of the destination so the destination is either entirely old
  or entirely new, never half-and-half.
- **Extended attributes, FIFOs, device nodes, sockets.** None of
  these have a use in the system we are building.
- **Caching layers above the block driver.** The card's
  controller caches; the kernel does not duplicate that work.
  Each box-level read or write is a small handful of block-level
  operations, sized so that latency stays predictable.

What's left after all those subtractions is: bytes at a path,
nothing else.

## The box abstraction

Six box kinds expose the filesystem to apps. They follow the
same dataflow contract as every other box — values arrive on
input ports, the function runs, the output value goes out on the
wire.

- **`read-path`** — input is a path string, output is the file's
  bytes. Output fires with the entire file's contents as a single
  value. For files larger than the box's slot capacity, the input
  port also accepts an optional offset and length so the consumer
  can stream chunks.
- **`write-path`** — inputs are a path string and a bytes value.
  Writes the bytes to the path, replacing whatever was there.
  Output fires with success-or-error as a small enum value. The
  write uses the temp-and-rename pattern internally, so a
  consumer downstream of `write-path` sees either the new file or
  the old file, never a half-written one.
- **`list-directory`** — input is a directory path, output is a
  list of names (no metadata — just names). A directory that
  doesn't exist is a hard error, not an empty list.
- **`delete-path`** — input is a path, output is success-or-error.
  Files and empty directories both delete; a non-empty directory
  is a hard error (the app must walk it first).
- **`path-exists`** — input is a path, output is a bool. The
  cheap predicate for "should I write here or read here first?"
- **`make-symlink`** — inputs are a link path and a target path,
  output is success-or-error. Creates a symlink at the link path
  that resolves to the target. See the symlink section below for
  how this works on FAT.

These six boxes are the entire filesystem surface that the apps
above ever see. Anything more (atomic-append, locking, watch-this-
file-for-changes) is built as a new box at the runtime layer when
a specific app demands it — not added to this surface
speculatively.

## Symlinks on FAT

FAT proper has no symlink concept. We add one ourselves, as a
one-sided convention that keeps the SD card readable on a laptop
without confusing the laptop's filesystem driver.

A symlink on the device is a regular FAT file whose contents
begin with an 8-byte magic header followed by the target path as
a null-terminated string. The header is the ASCII bytes
`SOSYMLNK` (`0x53 0x4f 0x53 0x59 0x4d 0x4c 0x4e 0x4b`) at offset
zero. The pattern is chosen so it cannot plausibly collide with
the start of any image file, soramech map file, message, or
program text the device produces.

The path-resolution logic inside `read-path`, `write-path`,
`list-directory`, and `delete-path` checks for the magic at file
open. If present, the box's behaviour redirects:

- `read-path` returns the target's bytes, not the link file's.
- `write-path` modifies the target, not the link file.
- `list-directory` shows the link's name in its parent directory,
  but a `path-exists` query on the link returns true iff the
  target exists.
- `delete-path` removes the link itself, not the target. To
  remove the target, the caller follows the link first.

A laptop reading the SD card sees the symlink as an ordinary tiny
file with weird binary contents. It does not break the laptop's
filesystem driver; the file just does not behave as a link from
the laptop's side. On the device, it does. The one-sidedness is
deliberate: the device-side software knows the convention; the
laptop-side software is uninformed and treats the file as data.

Symlink cycles are detected during resolution by counting hops
against a fixed maximum (say, 32). Hitting the cap is a hard
error the read-path box surfaces back to the caller, never a
silent hang.

## Persistence rules

The kernel commits to persistence in exactly these places:

- **`/settings/handedness`** — one byte: `r` or `l`.
- **`/settings/last-foreground-bottom`** — the name of the app
  the bottom screen was showing when the device last powered off.
- **`/settings/last-foreground-top`** — same for the top screen.
- **`/settings/drawer-swap`** — one byte: `0` or `1`, whether
  the center-button-to-drawer mapping is swapped.
- **`/drawings/`** — the painter's saved images.
- **`/programs/`** — the on-device editor's documents and the
  programming environment's maps. Each map is a directory under
  this prefix following soramech's existing layout (`meta.json`,
  `boxes/`, `src/`).
- **`/messages/`** — the messenger's stored conversations. One
  subdirectory per peer, one file per message inside.
- **`/models/`** — once the modeller ships in phase 10, the
  saved models live here.
- **`/peers/`** — the address book of peers we have ever talked
  to, by name and last-seen transport.

The kernel does *not* commit to persistence for:

- The navigation history. There is no back button and no history.
  See `004-input-model.md` and `005-display-and-compositor.md`.
- Open document state inside a foreground app. Coming back to
  the editor after switching to the painter shows the editor as
  it was — but only because the editor was running in the
  background the whole time. After a power cycle, the editor
  opens its last-saved file, not its mid-edit state.
- Anything under `tmp/`. That directory exists only in RAM and
  is the kernel-equivalent of the user-level RAM-symlinked
  `tmp/`. Crash logs, in-flight transcoder state, the JSONL ring
  buffer described in `009-deferred-work.md` — all of these live
  here and disappear on power-off.

## The USB-C inbox and outbox

When a laptop is plugged in by USB-C, the device exposes itself
as a USB mass-storage device with two directories
(`006-transport-and-networking.md` describes the transport
plumbing). The two directories sit at fixed paths in the
filesystem above:

- `/usb/inbox/` — write-only from the laptop's view, read-only
  from the device's. Files dropped here trigger the inbox watcher
  to dispatch them to the right app: an image becomes a paint
  attachment, a soramech map gets imported into `/programs/`, a
  text file opens in the editor.
- `/usb/outbox/` — read-only from the laptop's view, write-only
  from the device's. The device drops the laptop client installer
  here on every boot, plus anything an app explicitly offers for
  download.

Files in `/usb/` are RAM-backed, not persisted to the SD card.
The laptop only sees them while the cable is connected, and a
disconnect-then-reconnect clears the inbox so half-finished
imports don't replay.

## What's next

Phase 4 builds the SD card block driver, the FAT layer above it,
the six filesystem box kinds, and registers them with the phase 3
soramech runtime so apps can hold filesystem boxes in their maps.
Phase 6's drawer system has a "save" option in most apps that
emits a `write-path` box invocation under the covers.

`012-soramech-runtime.md` covers how the box abstraction here
attaches to the runtime above. `013-background-app-lifecycle.md`
covers how an app that has a file open survives being
backgrounded and resumed.
