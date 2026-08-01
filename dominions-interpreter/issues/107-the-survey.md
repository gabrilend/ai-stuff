# 107 — The survey

| | |
|---|---|
| Phase | 1 — The Reading |
| Blocks | nothing — it is the tool everything else is checked with |
| Blocked by | [103](103-the-header-without-the-file.md), [104](104-the-string-run.md), [105](105-the-record-arrays.md) |
| Related docs | [file formats](../docs/dominions-file-formats.md) |

## Current behavior

Nothing reports what the local collection contains. Every number about it — how
many savegames, what turns they are on, which versions wrote them, what record
stride they use — would have to be written into a document by hand, where it
would be wrong within a month.

## Intended behavior

A tool that reads the real files and reports the current truth, so that no
count, size, offset or stride is ever written as a literal anywhere else in the
project.

**The tool is the authority; the prose is only ever a description of shape.**
When a document and the survey disagree, the survey is right and the document
is stale.

### What it reports

Per savegame:

| Column | From |
|---|---|
| game | the folder name |
| started | whether a world state file exists |
| turn | the world state header |
| version | the world state header |
| nations | the turn files present |
| mods | the mod folders the save declares, and whether each exists on disk |

Across the collection:

| Figure | Why it is worth having |
|---|---|
| how many saves, how many started | the size of the test corpus |
| the distribution of versions | whether a format finding holds across versions |
| the distribution of record strides | whether the stride is a constant or a version-dependent number |
| the fraction of each file understood | the only honest measure of progress on this format |

That last one deserves its place. It will start small and embarrassing. It
should: a number that says *eleven percent of this file has been placed* is
worth more than a document that implies the format is solved because the parts
that were solved are the parts that got written about.

### The dominant cost is the one it must not pay

Reading a header is sixteen bytes. Reading a file is millions. There are over a
hundred savegames.

The survey reads headers for its per-save columns and opens whole files only
for the figures that genuinely require them — and when it does, it says so, and
it is a separate flag rather than the default. A survey that quietly reads
gigabytes to print a table of small integers will stop being run, and a tool
nobody runs is a document that lies.

### Written for reading aloud

The report is linear, one save per line for the table, one figure per line for
the summary. No columns that only line up in a fixed-width font, no information
carried by position or colour, no box drawing.

This is the accessibility rule applied to a developer tool, and it is applied
there on purpose: the first surface anybody builds is the one whose habits
spread.

## Suggested implementation steps

1. Walk `savedgames/`, one directory entry at a time.
2. For each, classify the files present and read the world state header if
   there is one.
3. Report per-save rows as they are computed, so a long run prints as it goes
   rather than after.
4. Check each declared mod folder against `mods/` and mark the missing ones.
5. Behind a flag, open whole files to compute stride distributions and the
   understood fraction.
6. Tests: every started save yields a turn in a plausible range and a real
   published version; every game name recovered equals its folder name; the run
   completes over the whole collection without an unhandled error, because the
   collection contains abandoned shells, duplicated folders and files from
   game versions two years apart, and all of those are the point.
7. Write the accompanying information file.

## Relevant files

- the local savegame collection
- the Dominions `mods/` folder
- `list-saves`, an existing shell script in the Dominions folder that infers
  what it can from the outside without opening files — worth reading, and worth
  superseding

## Open questions

- Should the survey learn to read a second collection, given one? Everything it
  knows was learned from one person's hundred savegames, and a second
  collection is the fastest way to find out which of those findings were
  actually assumptions.
