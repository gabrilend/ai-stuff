# strip-excluded.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/strip-excluded: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
strip-excluded
Issue 10-053: Remove excluded content from input/ so it never uploads.

WHAT IT DOES (for a CEO): the site is hosted by uploading the input/ folder
(the HTML points at the images there). Some content -- a regretted image, a
note -- should not ship. This deletes exactly those files from input/ after
the sync, leaving the originals untouched in their home folders. It runs every
build, so a re-synced file is stripped again; it never deletes anything it
was not told to.

VALIDATE-THEN-STRIP: before deleting anything, it checks that every
excluded_images entry actually resolves to a real file (either in input/ or in
the rsync source it came from). If any entry points at nothing -- a typo, or a
path that forgot a subdirectory -- it ERRORS and strips NOTHING, so a broken
exclusion can never silently fail and let the image ship anyway. Run early in
the build phase: a bad path stops you before the expensive catalog/embed
stages, so you fix config.lua and re-run cheaply. The `--check` flag runs only
this validation (no deletion).

PATH SHAPE: excluded_images entries are RELATIVE TO input/images/, e.g.
"my-art/usa-today/9.png". The "input/images/" prefix is implied and prepended
here -- it used to be repeated on every config line, carrying no information.

HOW: reads config.lua. For excluded_images it deletes each listed file. For
excluded_poems.notes it deletes the note's source file (the extractor already
keeps the note OUT of the generated poems, but leaves the source on disk).
The other text sources (fediverse/messages/bluesky) need no stripping: the
exclusion filter drops them during extraction so they never reach the
per-source poems.json, and their raw archives are gitignored and not uploaded.

Deletion uses Lua's os.remove (a direct file op, not a shelled-out rm).

Usage:
  lua scripts/strip-excluded [--dir PATH]            -- validate, then strip
  lua scripts/strip-excluded [--dir PATH] --check    -- validate only, strip nothing

--help: print the header above and exit, before any work (libs/script-help.lua)
```

## Inside (local to the file)

### `setup_dir_path(provided_dir)`
(No comment above it in the source.)

### `file_exists(path)`
(No comment above it in the source.)

### `build_source_map(cfg)`

```
excluded_images entries start with the source's input/images/ subdir name
(e.g. "my-art" or "fediverse-stars"). Map that to where the originals live so
validation can confirm the file is real even after a prior run stripped the
input/ copy. Note the name need not equal the source folder: fediverse-stars
syncs from .../fediverse-backup, and this map captures that.
```

### `image_resolves(entry, smap)`

```
Checks input/ first (present right after a fresh sync) and falls back to the
rsync source (stable across re-runs, when input/ was already stripped). Either
hit proves the exclusion targets something real; neither means it is broken.
```

### `validate_images(smap)`

```
Returns true on success. On failure it prints every offender and returns false
WITHOUT deleting anything (caller exits non-zero) -- validate-then-strip keeps
the operation atomic: all-good-then-strip, or stop and change nothing.
```

### `strip_one(rel)`
(No comment above it in the source.)

### `account(result, rel)`
(No comment above it in the source.)

### `strip_blacklist(entries)`
(No comment above it in the source.)

### `strip_whitelist(subdir, entries)`

```
source (exclude-by-default). Enumerates the synced input/ copy; the keepers
(validated to exist above) survive, everything else under the source is removed.
```
