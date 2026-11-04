# update-words.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/update-words: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Syncs words/notes/images from backup locations to project input directory
Preserves generated poems.json files to avoid redundant extraction

Issue 8-042: Added configurable image sync from config.lua
Issue 10-014: Migrated from input-sources.json to unified config.lua
Issue 7-003: Added --force flag to skip file preservation

The external sync-to-projects script does rm -rf input/, which would delete
the generated files that scripts/update creates. We preserve and restore them
so the freshness check works correctly.

Usage: scripts/update-words [--force]
  --force: Skip file preservation (regenerate everything from scratch)

--help: print the header above and exit, before any work (libs/script-help.sh)
```

## Functions

### `preserve_generated_files()`

```
Back up generated files before sync (they get deleted by rm -rf input/)
```

### `restore_generated_files()`

```
Restore generated files after sync
```

### `sync_external_files()`

```
Issue 10-003b: Use centralized external-sync module
Replaces the old sync_images_from_config() function
```
