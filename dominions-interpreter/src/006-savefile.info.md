# 006-savefile.lua

Reading a Dominions savegame, in two entrances.

A header read opens the file, takes sixteen bytes, and closes it. A full read
is separate, explicit and expensive. The turn number lives in the first handful
of bytes, the files it lives in run to millions of bytes, and there are over a
hundred savegames — one entrance answers "what turn is each of these on" in a
moment, the other would read gigabytes to print a column of small integers.

## Functions

| Function | Takes | Gives back |
|---|---|---|
| `kind_of(filename)` | a name or path | `"world"`, `"turn"`, `"orders"` or `nil`, and the nation |
| `header(path)` | a path | the header table, **or** `nil` and a reason |
| `describe(path, folder_name, front_bytes)` | a path, the folder to check the name against, how much to read | the header table plus the string run, **or** `nil` and a reason |
| `read_all(path)` | a path | every byte, **or** `nil` and a reason |
| `record_array(bytes, minimum_run)` | a whole file, the shortest run worth reporting | the array table, **or** `nil` and a reason |
| `placed_fraction(bytes, array)` | a file and its array | how much of the file the array accounts for, 0 to 1 |

## The header table

| Field | Type | Holds |
|---|---|---|
| `path` | string | where it came from |
| `kind` | string | `world`, `turn` or `orders`, decided by filename |
| `nation` | string or nil | from the filename; nothing inside a turn file identifies it |
| `version` | table | `{major, minor}` of the version that last **wrote** the file |
| `version_number` | number | the raw value, version times 100 |
| `turn` | number | as the game displays it |

`describe` adds:

| Field | Type | Holds |
|---|---|---|
| `game` | string | the name the file calls itself |
| `game_matches_folder` | boolean | whether that equals the folder name |
| `mods` | array | `{file, folder}` per enabled mod |
| `layers` | array | `{title, map}` per map layer |
| `version_text` | string or nil | the readable version string, which has been seen to disagree with the header |
| `unclassified` | array | strings fitting no known shape — the first sign of a format change |
| `records_from` | number | where the string run ended and the records begin |

## The record array table

| Field | Type | Holds |
|---|---|---|
| `stride` | number | the fixed part of a record, excluding the name and its terminator |
| `count` | number | how many records the run holds |
| `records` | array | see below |
| `tally` | array | every gap measured and how often, best first |
| `first_offset`, `last_offset` | number | where the array sits in the file |

A record:

| Field | Type | Holds |
|---|---|---|
| `name` | string | the only text in the record |
| `name_offset` | number | where the name starts |
| `offset` | number | where the record starts |
| `length` | number | stride plus name plus terminator |
| `raw` | string | the record's bytes, kept for phase 7 |

## Behaviour worth knowing before changing anything

**The signature is validated before any offset is trusted.** Every field is
read from a fixed position, and fixed positions in the wrong kind of file
produce numbers that look entirely real.

**The stride is measured, never written down.** `record_array` finds it per
file, every time, by tallying the gaps between names and taking the longest
unbroken run. A file whose stride disagrees with the collection's usual one is
*interesting*, which is how a format change in a new game version announces
itself. A hard-coded stride is how it would instead announce itself as silent
corruption.

**The whole tally comes back, not only the winner.** A file with two competing
strides has two arrays, and flattening that to one number loses one.

**Raw bytes are kept on purpose.** Phase 7 changes fields inside these records
without disturbing what surrounds them, and the experiments that establish
where those fields live need the originals to compare against.

**Minimum string length is two, not three.** A savegame in the collection is
called `H2`, and a three-character floor dropped its name entirely.

**Nothing here interprets a record beyond its name.** Only the name is readable
with confidence. Inventing plausible fields for the rest is the failure this
project exists to avoid.

## Related

- [The file format notes](../docs/dominions-file-formats.md)
- [The reading datapath](../docs/datapath-the-reading.md)
- [issues 103](../issues/103-the-header-without-the-file.md), [104](../issues/104-the-string-run.md), [105](../issues/105-the-record-arrays.md)
