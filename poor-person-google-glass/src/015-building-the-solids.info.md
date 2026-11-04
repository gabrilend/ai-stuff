<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 007 (from words to a model): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 015-building-the-solids

Solved parts into a shape record (issue 007d): each kind's solid made upright around the origin, turned to its axis by a true rotation, moved to its middle. Faces outward (helpers lent by 002).

| Offers | Takes | Gives |
|---|---|---|
| `build(solved, name)` | the solver's result, a name | a finished shape record (source_format "words", y up, units "units (1 = a default part's width)") |
