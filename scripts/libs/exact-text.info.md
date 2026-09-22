# exact-text.lua

Literal text search and replacement with a declared count. Text is compared
character by character, so nothing in it needs escaping, and a replacement
happens only when the text occurs exactly as often as the caller says. Load
with `dofile`; it returns a table.

| Function | Takes | Returns |
|---|---|---|
| `count(text, needle)` | two strings; `needle` must not be empty | number of non-overlapping occurrences |
| `replace_all(text, old, new)` | strings; `old` not empty | new text, number of replacements |
| `replace_exactly(text, old, new, expected)` | strings and a number | new text and the count on success; `nil` and the count found when the count differs |

`%` in the new text is not special (unlike `string.gsub`).

Used by `transcript-patches`. The upstream-patch skill ships the same rule as a
stand-alone command-line tool (`scripts/replace-exactly.lua` in the skill),
which stays separate because it is copied into other projects.
