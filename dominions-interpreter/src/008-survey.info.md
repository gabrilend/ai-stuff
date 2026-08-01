# 008-survey.lua

What the collection actually contains, read rather than remembered.

This exists so that no count, size, offset or stride is ever written as a
literal anywhere else in the project. The tool is the authority; the prose is
only a description of shape. When a document and this disagree, this is right
and the document is stale.

## Functions

| Function | Takes | Gives back |
|---|---|---|
| `one(home, game)` | the Dominions folder, a savegame name | the row table |
| `collection(home, each)` | the folder, a callback per row | all rows, and elapsed seconds |
| `summarise(rows)` | the rows | the summary table |
| `mods_present(home, mods)` | the folder, a mod list | per mod, whether its folder exists on disk |
| `deep(row)` | a row | the measurement table, **or** `nil` and a reason |

## The row table

| Field | Type | Holds |
|---|---|---|
| `game` | string | the folder name |
| `folder` | string | its full path |
| `started` | boolean | whether a world state file exists |
| `nations` | array of strings | every nation with a turn file |
| `turn` | number or nil | nil when the game has not started |
| `version` | table or nil | `{major, minor}` |
| `mods` | array | `{file, folder}` per enabled mod |
| `layers` | array | `{title, map}` per map layer |
| `game_in_file`, `game_matches_folder` | string, boolean | the standing check on the padding rule |
| `orders` | array | `{nation, path}` per orders file |
| `trouble` | string or nil | why this row could not be filled in |

## The summary table

| Field | Holds |
|---|---|
| `saves`, `started` | counts |
| `versions` | a map from version string to how many saves report it |
| `turn_low`, `turn_high` | the range across the collection |
| `name_disagreements` | saves whose file and folder disagree about the name |
| `troubled` | saves that could not be read, with reasons |

## The deep measurement table

| Field | Holds |
|---|---|
| `path`, `size` | which orders file, and how big |
| `stride`, `count` | the measured record stride and how many records |
| `placed` | the fraction of the file the array accounts for |
| `first`, `last` | the first and last names in the array |
| `tally` | every gap measured, best first |

## Behaviour worth knowing before changing anything

**A game that has not started has no turn.** Not zero. Turn zero is not a thing
that exists, and reporting it would destroy the difference between a game
awaiting pretenders and a broken file.

**The shallow pass reads sixteen bytes per save; the deep pass reads whole
files.** The deep pass is a separate request, never the default, and says so
while it runs. A survey that quietly reads gigabytes stops being run, and a
tool nobody runs is a document that lies.

**Rows are handed back as they are computed**, through the `each` callback, so
a long run prints as it goes — which is what stops somebody killing it because
they assumed it had hung.

**`placed` will be small and embarrassing.** It should be. A number saying
eleven percent of this file has been placed is worth more than a document
implying the format is solved because the solved parts got written about.

## Related

- [issue 107](../issues/107-the-survey.md)
- `010-survey-command.lua` — how a person runs this
