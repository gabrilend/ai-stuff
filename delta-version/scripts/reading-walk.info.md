# reading-walk.lua — info

Walks a reader through a project's map (from `reading-walk-map.lua`), one stop
at a time, in index order. No AI, no questions, nothing graded; walking from
the first stop past the last is a complete reading. Built for issue 065d.

## Use

| | |
|---|---|
| `reading-walk.lua <project>` | walk; builds the map first if the RAM tier has none |
| `--rebuild` | rebuild the map first |
| `--start=N` | begin at stop N (a walk begun partway is not called complete) |
| `--choices=LETTERS` | take choices from the string, one letter each; runs out → quit. For tests and demos. |
| `--map=FILE` | walk a map kept elsewhere |
| `--dir=PATH` | delta-version's home |

## Choices at each stop

| Letter | Does |
|---|---|
| n | next stop |
| m | where it is used |
| w | why: the recorded reasons, each with its source; or "no alternative was recorded here" |
| c | its own lines of code, marker to closing marker |
| s | skip: prints its one-sentence summary, then moves on. Typing "yeah yeah…" is the same. |
| f | skip the rest of this file: every remaining summary in it |
| b | back one stop |
| q | stop walking |

Ends with a receipt line: stops shown, skipped with summary, uses, reasons and
code looked at.

Tests: `test-reading-walk.sh`.
