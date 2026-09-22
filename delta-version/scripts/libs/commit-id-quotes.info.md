# commit-id-quotes.lua

Finds commit ids quoted in text and rewrites them to the ids those commits have
after a history rewrite. It is used by `graft-project-histories`, and can also
be loaded as a library with `dofile`, which is how its tests use it.

## What counts as a quoted id

A run of 7 to 40 lowercase hex digits is treated as a quoted commit id only if
all of these hold:

- No letter, digit or underscore touches either end of the run.
- It contains a letter a–f, or it is at least 8 characters long. A 7-digit
  number is treated as a number, not an id.
- It is the prefix of exactly one commit in the "before" universe. A prefix
  shared by two commits is ambiguous; it is left alone and reported.
- The map gives that commit a different new id.

A replacement keeps the length the id was written at. It is lengthened only
when a shorter form would be ambiguous in the "after" universe (old and new ids
together), or when a 7-character replacement would be all digits.

## Library functions

- `new_universe()` returns an empty set of commit ids.
- `universe_add(u, id)` adds a full commit id.
- `universe_from_file(path [, u])` reads one id per line.
- `matches(u, token)` returns every id that starts with the token.
- `map_from_file(path)` reads `old new` lines into a table from old id to new id.
- `map_problems(map)` returns a list of problems: two old ids sharing a new
  one, or an id that isn't full length. An empty list means the map is sound.
- `rewrite(text, ctx [, stats])` returns the rewritten text and a stats table.
  - `ctx` fields:
    - `before`: the universe the text was written against.
    - `after` (optional): the universe used to check new ids are unambiguous.
    - `lookup(old)`: returns the new id, or `nil` for a commit not rebuilt yet.
    - `out_len(token)` (optional): the length to write each id at.
  - `stats` counts `rewritten`, `lengthened`, `ambiguous`, `decimal_skipped`,
    `unmapped` and `pending`, and also holds `notes` and `restore_len`.

## Command-line modes

All modes except `translate` take the scratch directory. They are called by
`graft-project-histories` rather than by hand.

- `msg`: filter-branch's message filter. It reads the ids already rebuilt from
  `filter.map`.
- `scan-messages`: lists the commits whose messages hold ids to rewrite.
- `verify-messages`: the message gate.
- `tree`: rewrites the candidate text files, writes new blobs, prints the
  update-index lines, and runs the reverse check.
- `translate <map> <universe> <file>...`: rewrites files in place.
