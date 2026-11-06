<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 007 (from words to a model): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 013-reading-a-description

Sentences into statements, or refusals — all refusals in one pass, each with its line and the nearest word or part name (issue 007b).

| Offers | Takes | Gives |
|---|---|---|
| `read(description)` | the description text | model { parts = list of { name, kind, kind_word, colour, line }, statements = list }, refusals (list of { line, message }) |
| `sentences_of(text)` | | list of { line, text } (cut at full stops, not inside numbers; # lines skipped) |
| `words_of(sentence)` | | list of words: lower case, phrases joined with _, articles dropped, "N times" joined |
| `ratio_of(word)` | | number, or nil |
| `distance(a, b)` | | letter edits between two words |

A statement: { line, type, subject (part name), ... } — types declare, colour, extent (extent, ratio, other, other_extent), proportion (how, other), place (place, other), direction (axis), aligned (other). "it" as the other part means the subject (only for two different extents).
