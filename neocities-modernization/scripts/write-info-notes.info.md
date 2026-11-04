# write-info-notes.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/write-info-notes: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
write-info-notes

WHAT IT DOES (for a CEO): the house rule is that every program has a notes
file beside it (name.info.md) saying what it is, how to run it, and what
each of its usable functions takes and gives -- so a reader can learn a
program without reading its code. Most programs already say all of that in
their own comments. This writes the notes file from those comments: the
header at the top of the file, and each function with the comment above
it. It never overwrites a notes file that exists (one written by hand is
better than one written by this); a file it wrote says so on its first
line, and is refreshed by deleting it and running this again.

What counts as a function's comment: the comment lines directly above its
definition, skipping the fold markers ("-- {{{ ...", "# {{{ ..."). Lua
programs list their M.* functions as the ones others can use, and their
local functions as the inside; shell scripts list their functions.

Usage:
  scripts/write-info-notes [--dir PATH] --file REL [--file REL]...
  scripts/write-info-notes [--dir PATH] --missing
    --dir PATH   the project folder (default below)
    --file REL   a program, relative to the project folder; repeatable
    --missing    every program scripts/check-folder-flags counts that has
                 no notes file yet, tests left out (the project's tests
                 have never had notes files; each test's header says what
                 it checks)
    --include-tests  with --missing, the tests too
  A word with no flag in front of it stops the script (Issue 10-076).
Exit status: 0 when every requested file was written or already existed.

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `slurp(path)`
(No comment above it in the source.)

### `notes_path(rel)`

```
Where a program's notes live: name.info.md beside it, with .lua / .sh
dropped first (the project's existing notes are named both ways; the
shorter is checked too, so an existing one is always found).
```

### `is_shell(rel, text)`
(No comment above it in the source.)

### `header_of(lines, mark)`

```
The opening comment block, comment markers removed: everything from the
top (after a "#!" line) until the first line that is neither a comment nor
blank. Fold markers and the "--help" note line are left out.
```

### `comment_above(lines, n, mark)`

```
The comment lines directly above line n, fold markers skipped, in order.
```

### `functions_of(lines, shell)`

```
Each function definition: { name = "M.read(args, ...)", comment = {...},
external = boolean }, in file order.
```

### `render(rel, text, notes_name)`
(No comment above it in the source.)
