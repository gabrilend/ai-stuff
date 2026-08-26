# 028-match-parameters

Reads `input/` and assembles the record every program in this project starts from.

## What it is for

The first thing any program here does is read the `input/` directory. A match is a
small number of decisions made before it starts, and they live as one file per
decision rather than as command-line flags because they should be readable,
diffable, and copyable — anything you would pin down and hand to somebody else so
they can run the same match belongs there. A replay header is very nearly the same
set of fields.

**Everything here refuses rather than guesses.** A missing input file is named and
the program stops. Substituting a default for a match parameter would mean two
people running "the same" match and getting different games.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `load()` | — | The parameter record, below. |
| `root` | *(field, not a function)* | The project root, absolute, discovered from this file's own location. |

## The parameter record

| Field | Type | Meaning |
| --- | --- | --- |
| `root` | string | Project root, absolute. |
| `seed` | integer | The match seed. Everything random descends from it. |
| `team_size` | integer | Players per side. |
| `lane_count` | integer | The same number, named for what it decides. |
| `shape` | table | From [024-map-shape](../assets/024-map-shape.info.md). |
| `unit` | table | From [025-unit-table](../assets/025-unit-table.info.md). |
| `structure` | table | From [026-structure-table](../assets/026-structure-table.info.md). |
| `upgrade` | table | From [027-upgrade-table](../assets/027-upgrade-table.info.md). |

## The input files it reads

| File | Holds |
| --- | --- |
| `input/seed` | One integer. |
| `input/team-size` | One integer. Lane count follows from it. |
| `input/catalogues` | One catalogue path per line, relative to the root, loaded in order. |

The convention in all of them: a leading `#` is a comment, blank lines are
skipped, and the first line with content is the value. Everything after it is
ignored, so a file can carry notes below its answer.

## Two things it does that are easy to miss

**It finds the project root from its own location**, through `debug.getinfo`,
rather than being told. That is why the simulation runs identically under a bare
`luajit` from any directory and under LÖVE, with no path configuration in either.

**Catalogues are named in a file, not required in code.** A balance experiment
swaps one table by editing `input/catalogues`, without touching a line of Lua. The
key each one is filed under is its descriptive name with the index and extension
stripped, so `assets/025-unit-table.lua` arrives as `unit`.
