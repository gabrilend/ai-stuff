# sync-external-files.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/sync-external-files: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Issue 10-003b: CLI for external file syncing
Syncs files from external directories into the project's input/ directory.

Usage:
  ./scripts/sync-external-files           # Sync all sources
  ./scripts/sync-external-files --list    # List configured sources
  ./scripts/sync-external-files --source NAME  # Sync specific source by name
  ./scripts/sync-external-files --quiet   # Suppress output

Exit codes:
  0 - Success (all syncs completed or optional sources skipped)
  1 - Failure (required source missing or rsync failed)

Determine project root from script location
```

## Inside (local to the file)

### `parse_args()`
(No comment above it in the source.)

### `print_usage()`
(No comment above it in the source.)
