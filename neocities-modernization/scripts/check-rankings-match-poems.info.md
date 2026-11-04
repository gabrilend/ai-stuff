# check-rankings-match-poems.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/check-rankings-match-poems: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
check-rankings-match-poems -- confirms the saved similarity rankings were
built from the poem list the site is about to be built from.

WHAT IT DOES (for a CEO): every poem gets a number, handed out source by
source, and the saved "most similar poems" lists refer to poems by those
numbers.  Adding a single post renumbers every poem after it, so lists
saved before that point send every neighbour to the wrong poem -- pages full
of unrelated poems, with nothing reporting a problem.  This compares the
saved lists against the current poem list and image list, in seconds,
before a build starts, and says what does not line up.  It changes nothing.
(Issues 2-010, 10-069.)

Usage:  luajit scripts/check-rankings-match-poems [--dir PATH] --poems FILE --cache-dir PATH
  --dir PATH        project directory (default below)
  --poems FILE      the poem list the build will read
  --cache-dir PATH  the model's cache folder, holding similarity_rankings_cache.json
                    and image-manifest.json (from scripts/cache-dir)
  A word with no flag in front of it stops the script (Issue 10-076).
Exit status: 0 when they match, 1 otherwise.

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `read_json(path, what)`
(No comment above it in the source.)

### `expect(index)`
(No comment above it in the source.)

### `problem(text)`
(No comment above it in the source.)

### `sample(list)`
(No comment above it in the source.)
