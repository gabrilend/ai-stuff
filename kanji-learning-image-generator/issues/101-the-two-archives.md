# 101 — The two archives

## Current behavior

Nothing exists. There is a vision document and a set of empty directories.

## Intended behavior

**The project can get its own data, and can say afterwards exactly what it
took.**

Two files are needed and neither is ours (`docs/002`): KanjiVG for the strokes
and KANJIDIC2 for the meanings. Both are published, both are compressed, both are
around fifteen megabytes unpacked. A person who has just cloned this runs one
command and has them.

They are gitignored. Committing somebody else's versioned dataset puts it in this
history forever and makes every clone pay for it, and the version that matters is
the one the fetcher recorded, not the one that happened to be committed.

**Provenance is written down.** `assets/archive-provenance.txt` records which
release of each archive is on disk, its size, and when it was taken. A set of six
thousand images is generated against a specific dictionary, and *which* dictionary
must be answerable a year later without guessing.

**A missing archive is an error, not a condition to work around.** Every program
downstream that needs an archive and does not find one stops and says which
command produces it. It does not skip the character, does not substitute
anything, and does not carry on with an empty set.

## Suggested implementation steps

1. **The place where things are** (`src/009-where-things-are.lua`). Everything in
   this project needs to resolve a path relative to the project root, and the root
   is hard-coded with an argument override, as everything here is. This file also
   holds the two rituals every program observes: read `input/` at startup, write
   `output/goodbye` on the way out.

2. **The fetcher** (`src/010-fetch-the-archives.lua`). Downloads both archives,
   decompresses them into `assets/`, writes the provenance file. Uses `curl` and
   `gzip` because those are what a machine has; the point is not to reimplement
   HTTP.

   Skips a file already on disk unless told otherwise, since a fifteen-megabyte
   download that happens on every run is a download somebody will start avoiding.
   `--force` re-takes them.

3. **Verify against the shape, not against a hash.** A published archive changes
   between releases and a pinned hash would break the fetch every time upstream
   published. What is checked is that the file parses as the thing it claims to
   be: a KanjiVG that contains `<kanji id=` entries, a KANJIDIC2 that contains
   `<literal>`. A truncated download fails that and says so.

4. **The settings file** (`input/settings.lua`). Every knob in `docs/balance-updates.md`
   lives here, and this is where the startup ritual reads from. It is a Lua file
   returning a table, so a person editing it is editing data and cannot get a
   syntax surprise from a format that is trying to be clever.

## Related

`docs/002` — what is in each archive. `docs/006` — the phase this opens.
