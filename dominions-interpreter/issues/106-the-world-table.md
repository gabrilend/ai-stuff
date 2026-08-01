# 106 — The world table

| | |
|---|---|
| Phase | 1 — The Reading |
| Blocks | phases 2, 3, 4, 6, 7 — everything downstream reads this |
| Blocked by | [104](104-the-string-run.md), [105](105-the-record-arrays.md) |
| Related docs | [the reading](../docs/datapath-the-reading.md) |

## Current behavior

The pieces of a savegame can be read separately — header, string run, record
arrays — but nothing assembles them into one thing the rest of the program can
be handed.

## Intended behavior

One plain Lua table, built once per turn, passed by reference to everything
downstream. Structs and primitives. No framework, no lazy accessors, no
computed properties: **if a field is in the table it was read off the disk, and
if it is absent nobody found it.**

| Field | Type | Holds |
|---|---|---|
| `game` | string | the game name, which is also the folder name |
| `nation` | string | inferred from the turn file's name |
| `turn` | number | as the game displays it |
| `version` | table | `{major, minor}` of whatever wrote the file |
| `mods` | array | `{file, folder}` per enabled mod |
| `layers` | array | `{title, map}` per map layer |
| `provinces` | array | `{name, history, known}` |
| `commanders` | array | `{name, offset, raw}` |
| `unplaced` | array | `{offset, bytes}` for what was recognised and not understood |

A province's `history` is the game's own dated account —
`{when = "Early Winter in the year 2 of the ascension wars", what = "Ancyrna was
conquered by Pangaea"}` — parsed out of the event text that follows each
province's name in an orders file.

### The commander table is thin on purpose

Only the name is currently readable with confidence. Inventing plausible fields
for the rest — a strength, a location, a magic path guessed from a byte that
looks about right — is the exact failure this project exists to avoid, and it
is worse here than anywhere else, because a narrator hands it straight to a
person as prose.

The table grows one field at a time as each is established by experiment. Every
field it grows is one the narrator may then speak about, and not before.

### Built from the turn file, never the world state

`ftherlnd` knows everything every nation can see. `<nation>.trn` knows only
what this nation knows.

The world table is built from the turn file, and this is not a filter applied
afterwards. The turn file simply does not contain what the nation has not seen,
so a narrator built on it cannot leak an enemy's position even if asked to,
even if a model would happily oblige. **Correctness here comes from choosing the
right input**, which is far stronger than remembering to censor the wrong one.

`ftherlnd` is read for exactly one thing — confirming which turn the game is
actually on, since the world state is the authority — and nothing from it goes
anywhere near a model.

### Two entrances

A header read for the survey, cheap, sixteen bytes. A full read for a session,
expensive, the whole file. They are separate functions and the expensive one is
never called by accident.

## Suggested implementation steps

1. Define the table shape in the information file first, in full, down to the
   primitive types. Everything downstream is written against this description
   rather than against the code.
2. Assemble header, string run and record arrays into it.
3. Parse province event text into `{when, what}` pairs. The dated heading is
   recognisable by shape — a season, the words *in the year*, a number — and
   the lines that follow it belong to it.
4. Cross-check: the game name from the file against the folder name; the turn
   from the turn file against the turn from the world state. Report
   disagreements; do not reconcile them.
5. Keep `unplaced` populated. It is a feature.
6. Tests: a world table built from a known save has the right game name, a
   plausible turn, the six mods that save declares, three map layers, and a
   non-empty province list; the same save read twice produces equal tables; a
   pretender file produces a table with no provinces rather than an error.
7. Write the accompanying information file, which is the real deliverable of
   this issue.

## Relevant files

- the local savegame collection
- everything from issues 103, 104 and 105

## Open questions

- Are provinces in an orders file the ones this nation can see, or all the ones
  it has ever seen? The distinction matters for a narrator describing what is
  currently visible.
- Is `known` derivable at all, or is presence in the file the only signal? If
  presence is the only signal, the field should be dropped rather than filled
  with a constant.
