# 002-goodbye.lua

The receipt (`output/goodbye`) and the run log
(`tmp/shared-memory/<program>.log`) for every program. Format:
`docs/settings-files.md`, "output/goodbye".

Load by absolute path: `local goodbye = dofile(DIR .. "/src/002-goodbye.lua")`.
The module finds the monorepo's `scripts/` folder from its own location, so
it must be loaded by its full path.

## Data

**receipt** (returned by `start`):

| field | type | meaning |
| --- | --- | --- |
| `project_dir` | string | the project folder; `output/` and `tmp/` are under it |
| `program` | string | one word; names the receipt and log files |
| `seed` | string | as written in the receipt (`"none"` when unused) |
| `counters` | table: string → whole number | the tally |
| `log` | file handle | the run log, open for appending |
| `log_path` | string | where the run log is |

**read-back receipt** (returned by `read`): `{ program = string, ended =
string, seed = string, counters = table of string → number }`.

## Functions

| function | takes | gives |
| --- | --- | --- |
| `start(project_dir, program, seed)` | string, one-word string, string or number | a **receipt**. Makes sure the RAM scratch folders exist first. A missing seed is an error: pass `"none"` |
| `receipt:count(name [, amount])` | string, whole number (default 1) | adds to a counter |
| `receipt:set(name, value)` | string, whole number | sets a counter |
| `receipt:note(text)` | string | one time-stamped line in the run log |
| `receipt:text(ended)` | string | the receipt's text, counters sorted by name |
| `receipt:finish()` | — | writes `output/goodbye.<program>` and `output/goodbye` (each to a temporary name, then renamed), closes the log, returns the text |
| `read(path)` | string | a **read-back receipt**; error if there is no file |

## Environment

`EXEC_TIER_ROOT` and `ARTIFACT_TIER_ROOT` move the RAM scratch roots, which
only `tests/run-tests` does.
