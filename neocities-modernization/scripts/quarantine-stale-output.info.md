# quarantine-stale-output.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/quarantine-stale-output: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
quarantine-stale-output
Move files that no generated page points at out of output/ and into a
restorable holding area -- and put them back on demand. Nothing is deleted.

General description (for a CEO): the site build writes into output/, and the
upload step ships whatever it finds sitting there. Over months, output/ collects
files nothing links to any more: exports written by a code path that no longer
runs, debug dumps, rendered copies of source files that were deleted in spring.
They cost upload time and bandwidth, and they are invisible -- the build's own
cleanup sweeps only the file types it was told about, so anything else simply
accumulates. This tool asks one question of every candidate file, "does any page
we just generated point at this?", moves the answer-no files into a holding
area, and can move them all back if the answer was wrong.

Why it exists (Aug 2026): output/similar/ and output/different/ each held 7,904
.txt exports written by the single-threaded build path, which has not run since
29 June -- the threaded path (--threads > 1, i.e. every real run) never writes
them, and the --force cleanup in run.sh removes only *.html, so they survived
every rebuild untouched. 1.8 GB that no page linked to. An upload counts them;
phase-demo.sh, which filters on *.html, did not -- which is how the two numbers
came to disagree and the pile went unnoticed for six weeks.

THE SAFETY RULE, because this tool moves things: a file is a candidate only if
its name appears NOWHERE in the generated HTML. False positives (deciding
something is referenced when it is not) merely leave a stale file in place --
harmless. False negatives (deciding something is unreferenced when it is not)
would move a live file off the site. So every ambiguity is resolved toward
KEEPING the file, and the reference scan is deliberately over-generous: it reads
every HTML file under output/, not a sampled subset, and it counts a match
anywhere in the page, including inside poem text.

WHERE THINGS GO: tmp/shared-memory/quarantine/, which is /dev/shm -- RAM. Per
the tier rule in scripts/ensure-tmp-symlink, things you RUN live in tmp/ and
things you WRITE live in tmp/shared-memory/; held files are written data.
Being RAM, THE HOLDING AREA DOES NOT SURVIVE A REBOOT. That is the accepted
trade for an instant, disk-free hold. --status says how long it has been held.

Modes (exactly one; --plan if none given):
  --plan      list what WOULD move, grouped, with counts and sizes. Touches nothing.
  --move      move candidates into the holding area
  --restore   move everything in the holding area back where it came from
  --status    report what is currently held, and since when

Options:
  --group NAME   restrict --plan/--move/--restore to one group (repeatable)
  --quiet        suppress per-file listing in --plan

Usage:
  scripts/quarantine-stale-output --plan
  scripts/quarantine-stale-output --move
  scripts/quarantine-stale-output --restore --group media-flat-layout-orphans
  scripts/quarantine-stale-output --plan --dir /path/to/other/project/root

The project folder defaults to the hard-coded project root below; pass
--dir PATH to point the tool at a different checkout. A bare word stops the
tool (Issue 10-076).
```

## Functions

### `cleanup_work()`

```
The scratch directory holds the reference index and per-group file lists. It is
derived data with no value after the run, so it goes away on every exit path --
including a failure, where leaving a half-built index behind would tempt a later
run into trusting it.
```

### `ensure_holding_area()`

```
The holding area lives in RAM under tmp/shared-memory/. That symlink chain is
built by scripts/ensure-tmp-symlink, which is idempotent -- calling it here means
this tool works on a freshly-booted machine where /dev/shm is still empty. A
missing helper is a hard error rather than a silent mkdir: creating a plain
directory named tmp/ where a symlink belongs would quietly put 2 GB on the disk
the user was trying to spare.
```

### `urldecode_stream()`

```
Reads percent-encoded paths on stdin, writes decoded paths on stdout. The HTML
writes an apostrophe as %27, so "Statua-di-Sant%27Azraphel.png" in a page and
"Statua-di-Sant'Azraphel.png" on disk are the same file. Skipping this step
would report every such image as unreferenced -- exactly the false negative the
safety rule forbids.
```

### `build_reference_index()`

```
One pass over every generated page, producing the two lookup sets the collectors
consult. Reading ~1.4 GB of HTML takes a little while; it is done once and
reused, because doing it per-group would multiply the cost by the group count
for an identical answer.

Writes into $WORK:
  names.txt  -- every filename-with-extension token seen anywhere, basename only.
                Used for "is this export linked from anything?", where the file
                lives beside the pages and a bare name is how it would be written.
  media.txt  -- every token containing media/, with that prefix stripped, so the
                comparison keeps the subdirectory. This distinguishes the current
                my-art/about-face-2.png from the January flat-layout duplicate
                about-face-2.png; a basename-only test would conflate them and
                wrongly report the live one as the dead one.
```

### `collect_unreferenced_txt()`

```
Shared by the similar/ and different/ groups: the .txt exports sit beside the
pages, so a live one would be linked by bare filename. Anything whose name the
page corpus never mentions is an export from a build path that no longer runs.
$1 is the directory name under output/.
```

### `collect_similar_txt()`
(No comment above it in the source.)

### `collect_different_txt()`
(No comment above it in the source.)

### `collect_source_orphans()`

```
The source browser writes one page per project file plus an index that links
them all. When a project file is deleted, the next build simply stops emitting
its page -- but the previously-emitted page stays on disk, now unreachable. The
index is therefore the authority on what the browser currently contains, and
anything on disk it does not list is a rendering of a file that no longer exists.
```

### `collect_media_orphans()`

```
Top level of output/media/ ONLY, and the reason is a layout change: until
January the art lived flat as media/about-face.png; since 26 June it lives in
per-source subdirectories as media/my-art/about-face.png. Both copies are on
disk and only the subdirectory one is linked, so the flat copies are duplicates
of files the site still serves.

The subdirectories are deliberately NOT swept. A handful of images inside them
are unreferenced too, but in the CURRENT layout -- which reads as the gallery
failing to list them rather than the files being stale. Those want a person to
look, not a mover; see the open question in the accompanying report.
```

### `collect_debug_logs()`

```
Server and run logs from June, sitting in the directory that gets uploaded.
Logs belong in tmp/shared-memory/ per the project convention; these predate it.
```

### `collect_debug_binary()`

```
The GPU diversity stage writes this only when handed --save-binary, a debug
flag no scheduled run passes. The copy on disk is from January and is 243 MB.
```

### `collect_src_tempfile()`

```
An editor or generator left a .tmp.PID.HASH copy of a source file behind. It is
not under output/, so it never reaches the site -- it is swept here because it
is the same class of thing: a file nothing refers to, kept by nobody's decision.
```

### `group_selected()`

```
True when a group should be acted on: every group unless --group narrowed it.
```

### `human_size()`

```
Bytes as something a person reads. Only ever used for reporting.
```

### `sum_sizes()`

```
Total bytes of the newline-separated DIR-relative paths in file $1. Uses a NUL
handoff because these names contain spaces, ampersands and apostrophes
("D&D Sheet.pdf"), which any word-splitting approach would tear in half.
```

### `do_plan()`

```
Report only. Runs the same collectors --move runs, so what it prints is exactly
what would move; there is no second code path to drift out of agreement.
```

### `do_move()`

```
Moves each group into $HOLD/<group>/, mirroring the path relative to the project
root. That mirroring is what makes restore trivial and manifest-independent: the
holding area IS the map, so a restore cannot be desynchronised from a bookkeeping
file someone edited. The manifest exists for a human to read, not for the machine
to depend on.

rsync rather than a mv loop because this is a cross-filesystem move -- disk to
RAM -- so every file is a copy-then-unlink regardless, and rsync does the bulk
far faster than several thousand individual mv processes. -a preserves mtimes,
so a restored tree looks untouched to anything that compares timestamps.
```

### `do_restore()`

```
Walks the holding area and moves everything back to the path it came from. No
manifest is consulted -- the mirrored tree under each group directory already
encodes every original location, so restore stays correct even if a manifest was
lost or hand-edited.
```

### `do_status()`

```
What is held right now, and for how long. Reads only the holding area, so it is
instant -- no reference scan.
```
