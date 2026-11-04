# update.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/update: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Content extraction script with ZIP archive support
Automatically detects ZIP archives and extracts JSON data for poem processing pipeline
Implements freshness checking to skip extraction when outputs are up to date

--help: print the header above and exit, before any work (libs/script-help.sh)
```

## Functions

### `setup_dir_path()`
(No comment above it in the source.)

### `is_extraction_fresh()`

```
Check if extracted poems.json files are newer than source ZIP archives
Returns 0 (true) if fresh, 1 (false) if extraction needed
```

### `stop_extraction()`

```
stop_extraction <what failed>
One extractor failing stops the whole update. These used to print a warning
and carry on, so a build went ahead without that source's poems -- every
later stage (embeddings, similarity, diversity, pages: the better part of an
hour) then ran on a corpus missing a whole source, and the site was rebuilt
wrong before anyone read the warning. Stopping here costs seconds; the owner
would rather fix it now than finish a doomed run (2026-10-04).
```
