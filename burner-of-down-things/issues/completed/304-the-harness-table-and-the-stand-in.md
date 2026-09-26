# 304 — The harness table and the stand-in

The table of harnesses, and the first one: a model-free stand-in that plays
every kind of turn from fixtures ([005](../docs/005-datapath-the-hands.md),
*the harness table*).

## Current Behavior

Built as `src/037-the-harness-table.lua` and `src/038-the-stand-in.lua`. Rows carry `command` (the program line), `pool` and `limit`; the machine wraps every row's command in the same shell line (working folder, `timeout`, output to `result.json`, errors to `stderr.txt`, status to `exit`). The stand-in's script may key entries by "kind about" or "kind", may be a function of the turn (with an attempt count, so a fixture can fail and then succeed), and can misbehave four ways: write outside, write into the source, fail, hang. Checked by tests/040.

## Intended Behavior

- **The table:** rows with `name`, `needs`, `start` (turn folder,
  confinement → a command line), `cost`. Checking a row's needs runs
  `command -v` for each and refuses, naming what is missing.
- **Run one turn** (case, turn folder, harness): appends `turn-started`,
  runs the command with the time limit (`timeout`), captures its standard
  output into `result.json`, and returns the exit status. The verdict is
  written by the caller, after confinement (306).
- **The stand-in** is a Lua program (`src/…-stand-in.lua`) run as its own
  process: it reads `prompt.md`'s first line, which names the kind and about,
  and plays that kind from a **script**: a Lua file in the case folder,
  `stand-in.lua`, mapping kind (and optionally about) to what to write — file
  path and content, or a function of the prompt. A kind the script does not
  cover exits non-zero with the reason. A script entry may say `misbehave =
  "write-outside"` or `"fail"` or `"hang"`, so the checks can be tested.
- Fixture scripts for tests and demos live in `tests/fixtures/`.

## Suggested Implementation Steps

1. The table and needs check. **Test:** a row needing a missing program
   refuses by name.
2. Running a turn with a time limit. **Test:** a hanging stand-in is stopped
   at the limit and reported.
3. The stand-in. **Test:** each kind plays from a script; a misbehaving entry
   does what it says.

## Blocked by

- 301
- 303
