# 501 — A museum is a place you can name

## Current behavior

A style (`412`) is a row in a table inside `src/025-the-words-the-machine-reads.lua`:
words it adds, where in the sentence they sit, which refusals it lifts and why.
There is one, `photographic`. There is no notion of a *place* — nothing can be
asked for "in the manner of the Field Museum's dinosaur hall".

There are no photographs of any museum in this project, and none are planned
until a useful collection exists.

## Intended behavior

**`--style museum:<name>` asks for a picture in the manner of one particular
museum, and the museum is described in words.** With no photographs, the model's
own sense of the place does the work; the record's job is to name the place
precisely and briefly, and let the model fill in the rest.

**A museum is a record**, `input/museums/<name>.lua`:

| field | type | what it is |
|---|---|---|
| `name` | string | how it is written in a prompt ("the Field Museum, Chicago") |
| `halls` | list of strings | which kinds of exhibit it has — names from `502`'s closed list, so a museum cannot claim a hall the vocabulary cannot fill |
| `light` | string | how its cases are lit — a few dense words |
| `materials` | list of strings | the surfaces it is known by — a few dense words |
| `lifts` | list of strings | refusals lifted, under `412`'s rule: never the four |
| `why` | string | why the lifting is safe for this place |

"Museum" covers aquariums and planetaria as well — a museum is anywhere things
are put on display.

**A museum becomes a style, not a second mechanism.** Loading `museum:field`
builds a style row from the record, and `025` treats it like any style. It also
carries the museum's halls, which `502` chooses among. Both routes of `416`
share it.

**The museum is recorded in the pool**, as the style already is.

**Photographs come later** (`504`), as an addition to the record, not a
replacement for it.

## Suggested implementation steps

1. **A reader** — a small file in `src/` that loads a museum record and refuses
   a missing field or an unknown hall by name.
2. **`025.style(name)` learns the `museum:` prefix** and builds the style row.
3. **One museum written as the worked example.**
4. **Tests in `027`**: an unknown hall is refused by name; a museum asking to
   lift *kanji* is refused as a hand-written style would be (this also gives
   `412`'s never-liftable rule the test it has been missing since the
   Wimmelbild row, the only style that lifted anything, was removed); two
   museums give two seeds for one character.

## Open questions

- Which museum first?

## Related

`412` — what a style is. `502` — what a hall holds. `416` — the two routes that
share the style. `504` — photographs, later.
