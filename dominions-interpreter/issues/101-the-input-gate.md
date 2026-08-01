# 101 — The input gate

| | |
|---|---|
| Phase | 1 — The Reading |
| Blocks | everything; nothing can find a savegame until this exists |
| Blocked by | — |
| Related docs | [architecture](../docs/architecture.md), `input/game.example`, `input/cluster.example` |

## Current behavior

Nothing. The project has no way to learn where Dominions lives, which savegame
is being played, or which nation belongs to the player.

The local Dominions folder holds over a hundred savegames. Several of them
contain more than one turn file, because more than one nation has been played
in them. Any scheme that discovers the game by searching will eventually pick
the wrong one, and picking the wrong one means narrating a nation's private
view of the world to somebody who is not playing it — or, later, writing a turn
into a game nobody asked about.

## Intended behavior

The first thing the program does is read `input/`. That is where it learns how
to start; it is stated in the house rules and it is the right rule here for a
concrete reason, which is the paragraph above.

Two files:

| File | Holds |
|---|---|
| `input/game` | where Dominions lives, which savegame, which nation, where working copies go |
| `input/cluster` | the door roster — see phase 5; this issue only needs to find and parse it |

Both are `key value` lines, blank lines and `#` comments ignored. Both have a
`.example` beside them in the repository that documents every key in prose.

### What it answers

| Question | Returns |
|---|---|
| Where is the Dominions data folder? | a path, or a refusal |
| Where is the executable? | a path, or a refusal |
| Which savegame? | a folder name, checked to exist |
| Which nation? | a turn file name, **or a list of the candidates found** |
| Where do working copies go? | a path, created if absent |
| Where does this game's chronicle live? | a path, defaulted from the game name |

### Refusing, listing, and never choosing

If `nation` is absent, the gate does not choose. It returns the turn files it
found in the savegame folder and the caller asks the person. A savegame folder
holding one turn file is the common case and it is still not enough reason to
choose silently — the cost of being wrong is disclosing another player's fog of
war, which is invisible when it happens.

If a path in the configuration does not exist, that is an error naming the key
and the path, not a fallback to a guess. If the configuration file itself is
absent, the error says to copy the example, and names it.

### Paths

Everything the program touches is relative to one directory variable resolved
at startup, which defaults to the project root and can be overridden by
argument, so the program runs correctly from any working directory.

## Suggested implementation steps

1. Write the `key value` parser. It is small: trim, ignore blanks and comments,
   split on the first run of whitespace, keep later keys overriding earlier
   ones so a file can be appended to.
2. Resolve the project directory once and hold it. Every other path in the
   program derives from it.
3. Read `input/game`, validate every path it names by checking the filesystem,
   and return a settings table of plain strings.
4. Implement the nation resolution: if given, check the turn file exists; if
   not given, glob the savegame folder for turn files and return them as
   candidates.
5. Read `input/cluster` into an array of door records. Parse only — do not
   contact anything. Health checks belong to phase 5.
6. Create the working directory and the RAM scratch tiers if absent.
7. Tests: a settings file naming a real savegame in the local collection
   resolves; one naming a missing path is refused with the key named; one
   omitting the nation returns candidates rather than a choice; a savegame
   folder with several turn files returns all of them.
8. Write the accompanying information file.

## Relevant files

- `input/game.example` and `input/cluster.example`, which are the specification
- the local savegame collection, for tests that use real folders

## Open questions

- Should more than one game be playable in one session? The design assumes one
  game per run, which keeps the chronicle unambiguous. Two games in one
  conversation would need the chronicle to say which game each line belongs to.
