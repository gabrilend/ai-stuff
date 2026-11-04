# extract-notes.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/extract-notes.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Notes content extraction script
Processes text files from notes directory and extracts formatted content
```

## Inside (local to the file)

### `setup_dir_path(provided_dir)`
(No comment above it in the source.)

### `relative_path(absolute_path)`

```
Issue 7-003: Show project name instead of "./" when path equals DIR
```

### `shell_escape(str)`
(No comment above it in the source.)

### `get_file_mtime(file_path)`
(No comment above it in the source.)

### `format_iso_date(timestamp)`
(No comment above it in the source.)

### `generate_poem_metadata(content, file_path)`
(No comment above it in the source.)

### `is_valid_note_file(file_path)`
(No comment above it in the source.)
