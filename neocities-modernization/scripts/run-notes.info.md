# run-notes.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/run-notes: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
run-notes -- turns the notes folder into poems JSON.

Runs scripts/extract-notes.lua over input/notes. Called by scripts/update
during the build's update stage.

Usage:  scripts/run-notes [--dir PATH]

--help: print the header above and exit, before any work (libs/script-help.sh)
```

## Functions

### `setup_dir_path()`
(No comment above it in the source.)
