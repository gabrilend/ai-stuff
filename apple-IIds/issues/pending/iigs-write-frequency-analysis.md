---
name: GS/OS write-frequency analysis
phase: 5
status: pending (cannot start until 106 is done)
blockedBy: [106]
---

# iigs-write-frequency-analysis

Profile which GS/OS routines write most often, where they write, and
how much they write per write. The result informs the SD-card write
minimization work in phase 5 (issue 506).

## current behavior

We don't know what GS/OS writes when. Anecdotally, every Finder
window position adjustment, every desk-accessory state change, and
every desktop database update writes something. We need numbers.

## intended behavior

A report at `docs/research/iigs-write-frequency.md` containing:

- A ranked list of the top ~50 write sources in GS/OS by frequency
  (writes per minute under typical use).
- For each source: the trigger (what user action causes it), the
  target file or volume location, the typical bytes-per-write, the
  worst-case bytes-per-write.
- A separate ranked list by *bytes per minute*, since a small but
  frequent write may matter less than a large infrequent one
  (especially given SD-card erase-block sizes — small writes that
  fall within a single block coalesce naturally).
- A short narrative for the top 10 entries: why does GS/OS do this
  write? Could it be batched, deferred, or eliminated entirely?
- A short narrative for any write source that turns out to be
  surprising or removable.

The report references specific GS/OS source files and routine names
so a reader can go find the code.

## suggested implementation steps

(Can't start until issue 106 lands — we need GS/OS source built
under our toolchain.)

1. Add a tracing patch to GS/OS: at every File Manager entry point
   (`Open`, `Write`, `Close`, `Flush`, `Volume` ops, `Catalog` ops),
   record a trace line with: timestamp, calling routine, file path,
   bytes written, current call depth.
2. Run the device through a battery of representative user sessions:
   - boot + Finder idle (5 minutes)
   - open a document in a text editor, type for 10 minutes, save
   - open a paint program, draw, save
   - drag windows around the desktop
   - open/close several desk accessories
   - install software from a disk image to the shared volume
3. Aggregate trace lines into the two ranked lists.
4. Read the top-10 entries' source. Write the narrative.
5. Identify candidates for write coalescing or RAM-only caching, and
   open follow-up issues for each (in `issues/pending/`).

## why this is its own issue

Two reasons:

- **It produces a document, not code.** The output is an analysis
  that informs later code work. Treating it as a standalone issue
  keeps the analysis separable from any specific fix.
- **It needs the GS/OS source toolchain to exist.** Without issue 106
  we can't add the tracing patch. Putting this in `pending/` makes
  the dependency explicit.

## related documents

- `docs/001-architecture-overview.md` — operational constraints
  section, "minimize SD-card writes generally"
- `docs/004-roadmap.md` phase 5 issue 506 — the work that consumes
  this report's output
- `issues/106-gs-os-source-toolchain.md` — the prerequisite

## what this issue does *not* do

- It does not implement any write-minimization changes. Those are
  follow-up issues opened based on the report's findings.
- It does not benchmark SD-card wear directly (that would require
  long-duration testing with a wear-measurement methodology — out of
  scope here).
