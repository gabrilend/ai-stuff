# extract-bluesky-data.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/extract-bluesky-data: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Extracts posts from Bluesky CAR (Content Addressable aRchive) files
and transforms them into the unified poem format matching fediverse structure.

Simplified approach: Scans for CBOR post records instead of full CAR parsing

Usage: ./scripts/extract-bluesky-data [--dir PATH] [--car FILE] [--output FILE]
Default: the newest .car in input/bluesky/ -> input/bluesky/files/poems.json
A word with no flag in front of it stops the script (Issue 10-076).

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `find_car_file()`

```
Dynamically find any .car file in input/bluesky/ if not provided
```

### `scan_for_posts(data)`

```
Scans the raw file data for CBOR post records
```

### `main()`
(No comment above it in the source.)
