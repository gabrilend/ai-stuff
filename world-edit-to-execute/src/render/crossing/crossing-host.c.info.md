# crossing-host.c

The crossing-armies demo (issue 804): a raylib window whose every drawn
unit came from the server as bytes. Needs `CROSSING_DIR` (the project;
`run-crossing.sh` sets it) and `net-messages.h` (generated).

- **Usage:** `crossing-host [--check SECONDS [DELAY JITTER LOSS] | --shot SECONDS PATH [paused]]`.
  - no option: the window. Keys: D delay (0, 50, 100, 200, 400 ms), J
    jitter (0, 20, 60, 150 ms), L loss (0, 10, 30, 60%), C clear, S
    silence the stand-in player. While paused: the waiting dialog, with
    this player's slider draggable and vote buttons.
  - `--check`: no window; fails on overlapping units, a tick going
    backwards, a refused message, or fewer than half the expected states.
    Prints one line: states, tick range, overlaps, backwards, stale
    dropped, refused.
  - `--shot`: a picture; `paused` silences the stand-in and sets this
    player's slider to 0.5 s first, to show the dialog.
- **Threads:** the receiver (holds the only Lua state, runs
  `net/renderer_link.lua`, reads messages through a dispatch table of
  handlers, publishes unit states into the mailbox, drops states older than
  the newest shown), and the draw thread.
- **`cross_state`:** `tick` (`uint32_t`), `received_us` (`double`),
  `count` (`int`), `units` (≤256 `cross_unit`: `id` `uint32_t`; `x`, `z`,
  `vx`, `vz`, `facing` `float`; `walking` `int`).
- **`cross_news`** (under its lock): the waiting dialog's news, sliders,
  votes, each unit's path (≤128 points), counts, and the draw thread's
  wants (tolerance, vote, disturbance, silence).
