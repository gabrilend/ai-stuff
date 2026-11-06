<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 009 (tolerance calculations): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 019-a-calculation-and-its-checks

Loads one calculation file (format: docs/tolerances.md) and refuses it, naming every problem at once, if it breaks the format.

| Offers | Takes | Gives |
|---|---|---|
| `load(path)` | a calculation file's path | the checked calculation (named after its file) |
| `check(calculation, name)` | a table | the same table, checked; raises listing every problem |
| `UNITS` | | the set of allowed unit words |

A calculation: { name, question (string), inputs = list of { name, nominal, unit, minus, plus (numbers ≥ 0), from (string), condition (true or absent) }, outputs = list of { name, unit, at_least, at_most (numbers or absent) }, compute = function(values by input name) → values by output name }.
