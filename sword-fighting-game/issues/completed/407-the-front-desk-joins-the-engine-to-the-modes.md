# 407 — The Front Desk Joins The Engine To The Modes

| | |
| --- | --- |
| Phase | 4 — Seeing it |
| Blocked by | 103, 104, 405, 406 |
| Blocks | 502, 503, 701, phase 4 demo |
| Files | `main.lua`, `conf.lua`, `src/029-the-front-desk.lua`, `run-game` |
| Reads | `docs/datapath-run-lifecycle.md` |

## Current behavior

Built: `main.lua`, `conf.lua` (depth buffer, four-sample antialiasing,
unused modules off), `src/029-the-front-desk.lua` (seats, actions, button
actions and script events as tables; the tick accumulator; the receipt on
quit, after any pending screenshot is written), and `./run-game`. A lone
battle (`--mode battle`) skips the first command table; `--first-person`
starts in the line.

## Intended behavior

`main.lua` and `conf.lua` are unnumbered because the engine chooses their
names; main.lua only finds the project directory, sets the module path to
src/, and forwards every engine callback to the front desk.

**The front desk** holds the current mode — `command`, `third_person`,
`first_person`, `result` — and a dispatch table from mode to its handlers
(update, draw, key, mouse). Input events from the engine and from the
script go through one function per kind (key pressed, key released, mouse
pressed, mouse released, mouse moved), which looks the key up in the keys
table from the configuration and calls the bound action. The fixed-tick
accumulator lives here: real time is added, ticks are run while due, and
the script's due events are delivered before each tick.

On quit (escape, window close, or `--quit`), the front desk writes the
receipt — the last thing the program does.

`./run-game [options]` is the person's door: it makes sure the RAM tiers
behind tmp/ exist, runs the engine on the project directory with the
options, then files any screenshots (106).

## Suggested implementation steps

1. Write main.lua, conf.lua (depth buffer on, unused engine modules off).
2. Write the front desk with the modes table, the input dispatch and the
   accumulator.
3. Check with a scripted run that quits by itself and leaves a receipt.
