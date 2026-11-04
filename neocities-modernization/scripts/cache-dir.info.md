# cache-dir.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/cache-dir: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
cache-dir
Print the directory where a model's caches live, so SHELL scripts (run.sh,
generate-embeddings.sh) resolve the same location the Lua code does.

General description (for a CEO): the program keeps its big regenerable caches
in one place, and a single switch decides whether that place is the disk or
RAM (Issue 10-054). The Lua code asks a function for that place; the shell
scripts could not, so they hard-coded the disk path -- and when the switch was
flipped, shell wrote to disk while Lua read from RAM and the pipeline broke.
This tiny tool is the bridge: shell asks it for the path, so both sides always
agree no matter where the switch points.

Usage:
  scripts/cache-dir [--dir PATH] --model NAME        -> movable cache dir (embeddings_dir)
  scripts/cache-dir [--dir PATH] --model NAME --disk -> on-disk cache dir (diversity)
--dir PATH defaults to the hard-coded project root; pass it (as run.sh does) to be safe.

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `setup_dir_path(provided)`
(No comment above it in the source.)

### `parse_args(args)`
(No comment above it in the source.)
