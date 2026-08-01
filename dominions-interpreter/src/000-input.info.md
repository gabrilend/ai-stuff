# 000-input.lua

The first thing the program does: read `input/` and learn how to start.

Nothing here searches the disk for a game to play. The collection holds over a
hundred savegames and several hold more than one turn file, so a guess would
eventually narrate somebody else's private view of the world — a failure that
is invisible when it happens.

## Functions

| Function | Takes | Gives back |
|---|---|---|
| `configure(directory)` | the project root, a string | the normalised path; must be called before anything else |
| `directory()` | — | the project root; raises if `configure` was not called |
| `path(...)` | path segments, strings | them joined onto the project root |
| `read_pairs(path)` | a path | a table of string keys to string values, **or** `nil` and a reason |
| `game()` | — | the world settings table, **or** `nil` and a reason |
| `cluster()` | — | an array of door tables, **or** `nil` and a reason |
| `ensure_scratch()` | — | the shared-memory path, having created both RAM tiers |

## The world settings table

Returned by `game()`. Every field is a string unless noted.

| Field | Holds |
|---|---|
| `home` | the Dominions data folder, holding `savedgames/`, `mods/`, `maps/` |
| `binary` | the executable, for `--verify` and `--host` |
| `game` | the savegame folder name |
| `savegame` | the full path to that folder, checked to exist |
| `nation` | the turn file's nation — **absent if the settings did not state one** |
| `nations` | an array of strings: every nation with a turn file in the folder |
| `work` | where working copies are made |
| `chronicle` | where this game's record lives |

## The door table

Returned by `cluster()`, one per line of the roster.

| Field | Type | Holds |
|---|---|---|
| `name` | string | what to call it in a log |
| `host` | string | address |
| `port` | number | port |
| `kind` | string | `completion`, `embedding`, or `both` |

Parsing only. Nothing is contacted here; reaching a door belongs to phase 5.

## Behaviour worth knowing before changing anything

**A missing nation is a question, not a failure.** `game()` returns the table
whole with `nation` absent and `nations` listing the candidates. The caller
asks a person. A folder holding exactly one turn file is still not reason
enough to choose silently.

**Every path is checked where it is read, not where it is used.** A bad path
discovered halfway through a conversation has already cost the conversation.

**A later line overrides an earlier one.** A settings file can be appended to
rather than edited, and appending is what a person does when they are unsure.

**`ensure_scratch` runs every time.** `/dev/shm` does not survive a reboot, and
a script that assumes otherwise fails on the first cold morning.

## Related

- `input/game.example`, `input/cluster.example` — the specification, in prose
- [issue 101](../issues/101-the-input-gate.md)
