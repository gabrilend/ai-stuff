# zip-extractor.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/zip-extractor.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
zip-extractor.lua -- finds the source archives (the Mastodon export, the
chat export) among the input zips and unpacks the JSON the extractors read.
Called by scripts/update during the build's update stage.

Usage:  lua scripts/zip-extractor.lua [--dir PATH] --temp PATH
  --dir PATH   project folder (default below)
  --temp PATH  where to unpack (required)
  A word with no flag in front of it stops the script (Issue 10-076).

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `setup_dir_path(provided_dir)`
(No comment above it in the source.)

### `is_ignored_archive(basename)`

```
Check if a ZIP file should be skipped based on config.extraction.ignored_archives
```

### `get_file_mtime(file_path)`

```
Issue 7-005: Get file modification time for archive date comparison
```

### `relative_path(absolute_path)`

```
Issue 7-003: Show project name instead of "./" when path equals DIR
```

### `detect_archive_type(zip_file)`
(No comment above it in the source.)

### `detect_archives(input_directory)`
(No comment above it in the source.)

### `select_archives_by_type(archives)`

```
Issue 7-005: Groups archives by type, sorts by mtime (newest first),
returns selected archives and skipped (older) archives
```

### `extract_archive_data(archive_info, temp_base_dir)`
(No comment above it in the source.)

### `create_extraction_summary(archives, temp_base_dir)`
(No comment above it in the source.)
