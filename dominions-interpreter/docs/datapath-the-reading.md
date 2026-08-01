# Datapath — the reading

*A savegame becomes a table describing a world, and nothing else.*

## The path

    savedgames/<game>/<nation>.trn
              │
              ├─ header ──────► signature, version, turn number
              │
              ├─ string run ──► game name, mod dependencies, map layers
              │
              ├─ province records ──► places, and what this nation knows of them
              │
              └─ commander records ──► the officers, and where they stand
                        │
                        ▼
                  the world table
                        │
       ┌────────────────┼────────────────┐
       ▼                ▼                ▼
   the court       the herald        the ledger
  (who can be      (what is said)   (what an order
   spoken to)                        may refer to)

The map layers are read for their names only. The `.d6m` rendered map is never
opened; it is tens of megabytes of graphics and holds nothing this program
wants.

## The world table

One plain Lua table, built once per turn, passed by reference to everything
downstream. Structs and primitives, no framework, no lazy accessors — if a
field is in the table it was read off the disk, and if it is absent nobody
found it.

| Field | Type | Holds |
|---|---|---|
| `game` | string | the game name, which is also the folder name |
| `nation` | string | inferred from the turn file's name |
| `turn` | number | as the game displays it |
| `version` | table | `{major, minor}` of the version that wrote the file |
| `mods` | array of tables | `{file, folder}` for each enabled mod |
| `layers` | array of tables | `{title, map}` for each map layer |
| `provinces` | array of tables | see below |
| `commanders` | array of tables | see below |
| `unplaced` | array of tables | records recognised as records but not understood |

A province:

| Field | Type | Holds |
|---|---|---|
| `name` | string | as the game shows it |
| `history` | array of tables | `{when, what}` — the game's own dated account |
| `known` | boolean | whether this nation has seen it |

A commander:

| Field | Type | Holds |
|---|---|---|
| `name` | string | as the game shows it |
| `offset` | number | where the record starts, kept because the hand needs it |
| `raw` | string | the record's bytes, kept for the same reason |

The commander table is thin on purpose. Only the name is currently readable
with confidence, and inventing plausible-looking fields for the rest would be
the exact failure this project is supposed to avoid. It grows a field at a time
as each is established by experiment, and every field it grows is one the
narrator may then speak about.

## `unplaced` is a feature

A record the reader recognises as a record but cannot interpret goes into
`unplaced` with its offset and its bytes. It is not dropped and it is not
guessed at.

This costs a little memory and buys two things. The survey tool can report how
much of a file is currently understood, which is the honest measure of progress
on the format. And when a new field is worked out, the bytes to test it against
are already sitting in the table rather than needing another pass over the
collection.

## Reading the header without reading the file

The turn number lives in the first sixteen bytes. Answering "what turn is this
game on" must not read the rest, which runs to millions of bytes — across a
hundred savegames that is the difference between a survey that takes a moment
and one that reads gigabytes to print a column of small integers.

So the reader has two entrances. A header read opens the file, takes a few
bytes, and closes it. A full read is a separate, explicit, expensive call.

## The fog of war is structural

The world table is built from `<nation>.trn` and never from `ftherlnd`.

This is not a filter applied afterwards. The turn file simply does not contain
what the nation has not seen, so a narrator built on it cannot leak the enemy's
position even if asked to, even if a model would happily oblige. Correctness
here comes from choosing the right input, which is much stronger than
remembering to censor the wrong one.

`ftherlnd` is read for exactly one purpose — confirming which turn the game is
actually on, since the world state is the authority — and its contents go
nowhere near the doors.

## Refusing rather than defaulting

Every reader returns an answer or a stated reason it has none. None of them
return zero, empty string, or `nil` standing in for failure.

The distinction that matters most: a savegame in pretender-submission stage has
no world state file and therefore has no turn. That is a legitimate condition
and must be distinguishable from a damaged file, and both must be
distinguishable from turn zero, which is not a thing that exists.

## The mods problem, stated plainly

A save records which mods it needs. Six of them are loaded in one of the games
in the local collection. Mods add, remove and alter units, spells, items and
nations, so any lookup from a numeric identifier to a name is only correct in
the context of that game's mod list.

This project does not yet read `.dm` mod files. Until it does, the reader
reports the mod list and the narrator is not permitted to name anything it did
not read as text out of the save itself. Names that came out of the file are
safe; names that would come from a table of unit identifiers are not.

## Related

- [The file format notes](dominions-file-formats.md) — what the bytes are known to mean
- [The court datapath](datapath-the-court.md) — what the reading is turned into for the conversation
- [The hand datapath](datapath-the-hand.md) — why records keep their offsets and bytes
