# profile_txt.lua

Parses Warcraft III's INI-style profile text files (`Units\HumanUnitFunc.txt`
and similar), where some object data lives outside the SLK tables.

## Functions

| Function | Takes | Gives |
|----------|-------|-------|
| `parse(text, into)` | the file's text (string); optionally an existing result to add to | table: object id (string) → table of key (string) → value (string, as written after `=`) |

A repeated section adds to the first; a repeated key keeps the later value.
`//` lines and blank lines are ignored.
