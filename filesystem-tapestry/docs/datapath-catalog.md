# Datapath — The Catalog

This document traces one datum — a single file on disk — from the moment the
scanner meets it to the moment a person opens it. Update this document when the
shape of the catalog record changes.

## 1. A file on disk

The raw material is a file somewhere under one of the configured **roots**
(the user's data drives). All we can learn about it cheaply is what the
filesystem already knows: its path, its size, and its timestamps.

On ext4 (all the roots here) the filesystem records a true **birth time**
(crtime), reachable through `stat`'s `%W` field. This is the "created" date.
The "modified" date is `mtime` (`stat`'s `%Y`). Both are captured in seconds
since the epoch. If a filesystem ever reports birth time as unknown (`%W` = 0),
the scanner falls back to modified time for the "created" field **and flags the
record** so the fallback is visible, never silent.

## 2. The scanner reads it  →  a catalog record

`src/03-cataloger.lua`, run once per root, produces one record per file:

    {
      path      = "/mnt/cmdo/ritz/my-recorded-videos/2024-03-06_20-02-41.mkv",
      created   = 1709780561,   -- birth time, epoch seconds
      modified  = 1709780561,   -- mtime, epoch seconds
      size      = 8021714852,   -- bytes
      kind      = "video",      -- media class, from extension (see dispatch)
      excluded  = false,        -- true if path matched the shared .gitignore
      created_is_fallback = false  -- true if birth time was unavailable
    }

Records for one root are written as a **shard** into the RAM-backed tmp
directory (`tmp/catalog-<root-tag>.jsonl`), one JSON object per line. Roots are
independent, so one scanner process runs per root, in parallel — never one
thread grinding through all five drives in sequence.

## 3. Exclusion is stamped, not dropped

While scanning, each path is tested against the **shared exclusion matcher**
(`libs/02-exclusion.lua`), which is built by parsing the unified `.gitignore`
that delta-version maintains at `/mnt/mtwo/programming/ai-stuff/.gitignore`.
A matching path is **not discarded** — its record is written with
`excluded = true`. This is the "excluded but referenced chronologically" rule:
the file stays in the timeline; it is only the *walk* that skips it.

## 4. Merge  →  one catalog

`src/04-catalog-store.lua` concatenates the per-root shards into a single
catalog at `assets/catalog.jsonl` and can load it back into memory. This is the
boundary between the two halves of the system: everything before this point is
**generation**; everything after is **viewing**. They share this file and
nothing else.

## 5. Ordering  →  an index, not a copy

`src/05-ordering-engine.lua` never moves the records. It produces an **ordering**
— an array of catalog indices in the order you should walk them:

- **chronological**: sort by `created` or `modified`, ascending or descending.
  Includes excluded files if asked, but the navigator's default walk skips them.
- **similar** (Phase 2): nearest neighbours by cosine over policy embeddings.
- **different** (Phase 2): greedy diversity chain over the same similarities.

When Phase 2 data (policy embeddings) is absent, `similar`/`different` **fall
back to chronological and say so** — the ordering is never silently wrong.

## 6. The cursor  →  a program

`src/09-navigator.lua` holds a cursor: an offset into the active ordering.
`next`/`previous` move it (skipping excluded records in browse mode). `open`
takes the record's `kind`, looks it up in the **media dispatch table**
(`libs/08-media-dispatch.lua`), and launches the matching program — mpv, neovim,
feh, zathura — or, if the kind is unknown, `xdg-open` **with a printed warning**
that a fallback was used.

## Record field reference

| field                 | source            | meaning                               |
|-----------------------|-------------------|---------------------------------------|
| `path`                | find              | absolute path                         |
| `created`             | stat `%W`         | birth time, epoch seconds             |
| `modified`            | stat `%Y`         | mtime, epoch seconds                  |
| `size`                | stat `%s`         | bytes                                 |
| `kind`                | extension lookup  | video / audio / image / text / doc / other |
| `excluded`            | exclusion matcher | matched the shared `.gitignore`       |
| `created_is_fallback` | scanner           | birth time was unavailable, used mtime|
