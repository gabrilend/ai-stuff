# 018-the-harness

Finds a source module by its stem, asserts, and reports; every test program
starts here.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

The tests were written before the source. A test therefore cannot name a file's
number, only its **stem**, and this harness finds the one file in `src/` (or
`assets/`) whose name ends in that stem. Zero matches is a **named absence** —
the file looked for and the issue that creates it — and the suite that asked
fails. There are no skips: an absence is a failure by design.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `start(arguments, name)` | the program's `{...}`, and its name | nothing; reads `--dir` and prints the header |
| `seed()` | — | the integer seed from `SDC_SEED`, or the pinned default |
| `load(stem, issue)` | a stem such as `"the-dunes"`, an issue number as a string | the module the file returns; raises a named absence if it is missing or duplicated |
| `load_asset(stem, issue)` | the same, for `assets/` | the catalogue table |
| `check(name, condition, detail)` | a claim, whether it held, an optional explanation | nothing; counts and prints |
| `suite(name, body)` | a group's name and a function | nothing; runs the body, catches a named absence as one failure |
| `same_numbers(a, b)` | two flat arrays | `true`, or `false` and where they first differ |
| `finish()` | — | never returns; prints the tally and exits non-zero on any failure |

## Data structures it owns

- `root` — string; the project root, from `--dir` or hard-coded.
- `passed`, `failed` — integers.
- `absent` — a list of strings, one per subject the run could not find, printed
  at the end so a reader sees what has not been built yet in one place.
