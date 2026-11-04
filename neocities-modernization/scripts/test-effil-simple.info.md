# test-effil-simple.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/test-effil-simple: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
test-effil-simple -- checks that the threading library (effil) loads and
runs a thread, by starting one and reading back its result.

Usage:  scripts/test-effil-simple [--dir PATH]

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `worker(x)`

```
Simple worker function
```

### `file_worker(filename, content)`

```
Test with file I/O
```
