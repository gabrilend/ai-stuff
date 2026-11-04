<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 007 (from words to a model): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 014-solving-the-relations

Statements into numbers, in three passes (sizes, directions, places), each part after every part it mentions (issue 007c).

| Offers | Takes | Gives |
|---|---|---|
| `solve(model)` | the reader's model | result { parts, assumptions = list of { part, text }, anchor = name }, refusals |
| `half_extents(part)` | a solved part | { x, y, z } half sizes in the world |
| `AXIS_LAYOUT` | | part axis → which extent lies on world x, y, z |

A solved part: name, kind, line, colour ({r,g,b}), colour_word, extents { along, across, deep } (numbers, in units where a default part is 1 wide), axis ("x"/"y"/"z"), centre {x,y,z}. Refuses circles, conflicts, unplaced parts and rings with no hole.
