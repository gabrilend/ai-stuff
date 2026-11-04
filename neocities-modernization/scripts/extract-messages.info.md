# extract-messages.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/extract-messages.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Messages content extraction script
Parses exported message JSON and extracts formatted content
```

## Inside (local to the file)

### `setup_dir_path(provided_dir)`
(No comment above it in the source.)

### `relative_path(absolute_path)`

```
Issue 7-003: Show project name instead of "./" when path equals DIR
```

### `format_date(timestamp)`
(No comment above it in the source.)

### `format_iso_date(timestamp)`
(No comment above it in the source.)

### `generate_timestamp(timestamp)`
(No comment above it in the source.)

### `generate_iso_timestamp(timestamp)`
(No comment above it in the source.)

### `generate_poem_metadata(content, source_data)`
(No comment above it in the source.)

### `build_image_lookup(extract_dir)`

```
Matrix exports store decrypted images alongside export.json
Matrix renames files to: {original_basename}-{M-D-YYYY} at {H-MM-SS AM/PM}.{ext}
We need to map both exact and prefix matches
```

### `is_bare_filename(body)`

```
Returns true if the body looks like just a filename (no meaningful text)
```
