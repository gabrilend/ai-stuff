# 10-053: Exclude Content by Path/ID and Strip It From input/ Before Upload

## Status
- **Phase**: 10 (Developer Tooling)
- **Priority**: Medium
- **Type**: Feature
- **Status**: Open
- **Related**: 6-031 (excluded_poems / tombstoning), `libs/exclusion-filter.lua`

## Current Behavior

Poem exclusion exists via the `excluded_poems` config (Issue 6-031), read by
`libs/exclusion-filter.lua`. It **tombstones**: during extraction the listed
poems are skipped so they never enter the generated `assets/poems.json` (and thus
never reach the HTML), while leaving a gap in the ID sequence so anchor links
stay stable. It does NOT touch `input/` -- the excluded poem's source file
remains. There is **no image-exclusion mechanism at all**.

This matters because `input/` is uploaded to host the site: the HTML references
images by relative path (`../../input/images/...`, `../../input/media_attachments/
...`), so the image files must ship. As a result:
- An unwanted image cannot be removed from the site without deleting it by hand.
- An excluded poem's raw source still ships inside `input/` (privacy leak: the
  text is gone from the HTML but present in the uploaded source data).

Note: `.gitignore` does not help here -- it keeps files out of git, but a
physically-present file in `input/` still uploads.

## Intended Behavior

One consistent exclusion system for images AND text, where exclusion also REMOVES
the source from `input/` so it never uploads:

- **`excluded_images`** (new config): a list of paths **relative to
  `input/images/`** -- i.e. `<source>/<path-within-source>` such as
  `my-art/usa-today/9.png`. The `input/images/` prefix is implied (prepended by
  the strip script) rather than repeated on every line. Excluded images are never
  cataloged, embedded, flattened into `output/media`, or rendered.
- **Build-start validation (hard error).** Before stripping anything,
  `strip-excluded` resolves every entry back to a real file -- the `input/images/`
  copy if present, else the entry's rsync source (so it still validates after a
  prior run already stripped `input/`). Any entry that resolves to nothing is a
  FATAL error: the script prints the offenders, strips nothing, and exits
  non-zero; `run.sh` aborts the build. This closes the silent-failure hole where a
  mistyped path (e.g. omitting a subdirectory like `kooky-dookerie/`) let the
  image ship anyway. A `--check` flag runs only the validation (no deletion), for
  a cheap pre-flight. Validation precedes the catalog/embed stages, so a bad path
  stops the build before any expensive work and the re-run is cheap.
- **`excluded_poems`** (existing): keep the tombstone (stable anchors) AND strip
  the source from `input/`.
- **A post-sync strip step** (`scripts/strip-excluded`) deletes the excluded
  sources from `input/` AFTER rsync/extraction but BEFORE the catalog/embedding/
  HTML stages (and before upload). It is idempotent and logs every path it
  strips. The originals stay safe in the `/home/ritz/...` rsync sources, so a
  later sync simply re-copies them and the strip removes them again.

### Per-source strip semantics (because input/ is shaped differently per source)

- **images / media**: individual files -> delete the file.
- **notes**: individual files (`input/notes/<id>`) -> delete the file.
- **fediverse / messages / bluesky**: NOTHING to strip. The exclusion filter
  (`exclusion-filter.lua`) runs during raw extraction
  (`extract-fediverse.lua:606`, notes, messages), so excluded poems never enter
  the per-source `input/<source>/files/poems.json`; and their raw archives
  (`outbox.json`, `*.car`, `*.zip`) are `.gitignore`d + "DO NOT TRACK", so they do
  not upload. The strip script logs the count for transparency but acts only on
  images and note source files.

Once the files are gone, the downstream stages need no special-casing: the image
catalog and the media flattening simply do not find them, and the embedding /
HTML stages never see them. The tombstone in `exclusion-filter.lua` still governs
ID stability for the combined sources.

## Design Notes

- **Strip, don't just filter.** Filtering keeps content out of the HTML but not
  out of the uploaded `input/`. The delete is the only thing that prevents upload.
- **Idempotent + safe.** Stripping an already-absent path is a no-op; the rsync
  sources are the source of truth, so nothing is irrecoverable.
- **Ordering.** Runs after the extraction stage (so the combined poems.json
  exists to filter) and before cataloging images (so excluded images never enter
  the catalog).
- **Logging.** Every stripped path is logged (counts per category), and a
  configured-but-missing path is a warning, not a silent skip.

## Suggested Implementation Steps

1. Add `excluded_images = { ... }` to `config.lua` (next to `excluded_poems`),
   documented with the relative-path format.
2. New `scripts/strip-excluded` (hard-coded `${DIR}` + arg override): reads both
   config lists; deletes excluded image/note files; rewrites the combined
   per-source `poems.json` to drop excluded IDs; logs counts and any misses.
3. Wire it into `run.sh` immediately after the extraction stage, before image
   cataloging.
4. Confirm the catalog / media-flatten / embedding / HTML stages behave correctly
   with the excluded content simply absent (they should, with no code changes).
5. Document the relative-path discovery (how to find an image path or poem ID to
   exclude) in the config comment, mirroring the `excluded_poems` comment.

## Related Documents / Tools

- `config.lua` -- `excluded_poems`, the new `excluded_images`.
- `libs/exclusion-filter.lua` -- the tombstone filter (kept for ID stability).
- `scripts/update` / `scripts/zip-extractor.lua` -- where input/ is populated.
- `run.sh` -- where the strip step is wired in.
- `/issues/completed/6-031-*` -- the original poem-exclusion design.
