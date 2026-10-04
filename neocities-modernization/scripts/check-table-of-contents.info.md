# check-table-of-contents

Checks `docs/table-of-contents.md` both ways: every path it lists exists, and
every tracked file under `docs/` and `notes/` is listed.

## Why it exists

On 2026-10-04, 56 of the 125 paths in the table of contents named files that
had moved or been deleted, and several documents were not listed at all.
Nothing had noticed, because nothing checked.

## Usage

    scripts/check-table-of-contents [DIR]

Exit status: 0 no findings, 1 findings printed, 2 no table of contents.

## Findings

| Finding | Meaning |
|---|---|
| `missing   /path` | the table of contents lists a path that does not exist |
| `unlisted  /path` | a tracked file under `docs/` or `notes/` that the table of contents does not mention |

A path is any backticked text starting with `/`. Backticked text containing a
space counts as a path only if it ends in a file extension or a slash, so a
command written in backticks is not mistaken for one. A listed folder (ending
in `/`) covers every file inside it.

## Test

`scripts/check-table-of-contents.test.sh` checks both findings, folder coverage,
and that a backticked command is ignored.
