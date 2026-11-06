# 103 — A Run Starts From Input And Ends With A Receipt

| | |
| --- | --- |
| Phase | 1 — The spine |
| Blocked by | 101 |
| Blocks | 104, 105, 407 |
| Files | `src/018-input-and-goodbye.lua`, `input/`, `output/goodbye` |
| Reads | `docs/datapath-run-lifecycle.md` |

## Current behavior

Built in `src/018-input-and-goodbye.lua`: input/*.lua read first into run
options (seed, mode, region, first_person, script, quit, report, receipt,
perks, mods); unknown options stop the run naming the file. The receipt
writer serves the window (`src/029-the-front-desk.lua`) and the headless
runner (`src/020-headless.lua`); a reader turns receipts back into fields for
the batch totals. Tested in tests/031-the-spine.lua.

## Intended behavior

**The first thing a run does is read input/.** Every `*.lua` file there
(in name order) returns a table of run options: `seed` (integer), `mode`
(string: "match", "battle", "duel"), `script` (a list of scripted events in
the same form the command line gives), `first_person` (boolean: start the
battle in the front rank). Command-line options are laid over the files, so a
flag beats a file. A file that does not return a table, or names an unknown
option, stops the run with the file's name.

**The last thing a run does is write output/goodbye.** The receipt is a short
text file of `name: value` lines:

- `ended` — the wall-clock time the run ended
- `seed`, `mode`
- `ticks` — simulation ticks run; `seconds` — simulated seconds
- `frames` — frames drawn (0 when headless)
- `swings`, `hits`, `criticals`, `parries`, `trips`, `falls`, `volleys`
- `rounds`, `result` (who won the match or battle, or "unfinished")
- `stream draws` — one line per random stream
- `screenshots` — how many were taken

The receipt is written by one shared writer that both the window and the
headless runner call on a clean exit, so no front end can forget it. A crash
writes nothing; a missing or stale receipt is the crash report. The same
counts are kept in a counters table on the battle record (see 305), so the
receipt is a reading of state, not a second tally.

## Suggested implementation steps

1. Read input/ with plain `io` from the project directory (the engine's
   sandboxed filesystem cannot see it), sandboxing each file with an empty
   environment.
2. Write the receipt writer; it makes output/ if it is missing.
3. Test: a file in a temporary input folder sets the seed; a bad file stops
   the load; the receipt names every counter.
