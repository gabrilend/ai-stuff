# 301 — The notes command

The program a person runs.

## Current Behavior

Nothing is built yet.

## Intended Behavior

`notes.lua` at the top of the design, run with LuaJIT, using 101, 102, 103,
201 and 202. It finds its modules relative to its own location, so it works
from any folder. Notes are kept in the file named by the environment
variable `NOTES_FILE`, or `notes.txt` in the current folder.

| Command | Does | Prints |
|---|---|---|
| add <words…> | joins the words with spaces into the text; stamps today's date; parses the tags; gives the next id; saves | `added <id>` |
| list | | every note, as 201's list |
| list <tag> | | only notes with that tag |
| find <word> | | notes holding the word, as 202 finds them, shown as 201's list |
| anything else, or nothing | | a one-line usage message, and exits 1 |

## Suggested Implementation Steps

1. add and list. Test: two adds then list shows both, in order, with ids 1 and 2.
2. list by tag and find. Test: each selects the right note.
3. usage. Test: an unknown command exits 1.

## Acceptance

```sh
luajit tests/301-the-notes-command.lua
```

## Blocked by

- 101
- 102
- 103
- 201
- 202

## Covers

- notes.lua
