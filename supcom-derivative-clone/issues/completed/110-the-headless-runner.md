# 110 — The headless runner

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 102, 105, 109 |
| Blocks | 609, 901, 902 |
| Reads | [the views](../../docs/010-the-views.md) |
| Open questions | A2 |

## Current behavior

Built. `src/037-headless-runner.lua` reads `input/seed`, `input/field` and
`input/players`, assembles the world, records a replay log in the RAM tier,
plays to the tick limit and returns a report, writing `output/goodbye` last.
Given a log it replays it and names the first tick whose hash differs.
`./run-headless` at the project root is its front door, with `--ticks`,
`--seed`, `--replay`, `--draw` and `--colour`.

## Intended behavior

A program that plays a match with no window and says what happened. It is the
first thing in the project that runs the simulation end to end, it is what the
tests drive, it is what plays ten thousand matches overnight, and it is what
the phase 1 demo is.

`run(root, options)` does, in order:

1. **Reads `input/` first.** The seed (or draws one, and appends it to the
   seed notebook in the RAM tier), the field's shape parameters, the players and
   their teams, which catalogue tables to load. An option on the command line
   beats the file for any of them; the environment's seed beats both.
2. Raises the field, assembles the world, opens the replay log in the RAM tier.
3. Loops `advance` until the tick limit in the options or until the tick says
   the match has ended, whichever comes first.
4. Returns a **report** table: the seed, the ticks run, the final hash, the
   number of sightline questions asked and the seconds they took, the wall
   time, what ended the match, and where the replay was written.
5. **Writes `output/goodbye` last**, with the report in a few lines.

A root script, `run-headless`, is the front door: it hands the project root
and the command-line options to `run` and prints the report. The phase 1 demo
runs it twice on one seed and shows the two hashes side by side, equal.

Nothing in the runner draws. If a picture is wanted, the terminal viewer is
given the final snapshot; the runner only hands it over.

## Suggested implementation steps

1. Claim the file with `./new-source-file --summary "Plays a match with no window and reports." headless-runner`.
2. Write the reader for `input/seed`, `input/field`, and `input/players`, each
   refusing a malformed line by name rather than defaulting.
3. Write `run(root, options)` as the sequence above.
4. Write the report as a table and the one function that renders it as lines.
5. Write `run-headless` at the project root: the hard-coded `${DIR}`, the
   override, the options, and the call.
6. Add the input files the reader expects, with their explanatory comments,
   and mention them in `input/what-to-start-with`.
7. Fill the companion with the report's fields.

## What happened

- **Replaying lives in the runner.** Issue 109 describes a runner that feeds a
  log to a fresh world and compares hashes; this is that runner, so `--replay`
  is an option here rather than a second program. A log whose stamp differs
  from the match it would make is refused; with no tick limit a replay runs
  just past the last tick its log holds.
- **The seed's precedence is the issue's**: the environment beats an option,
  which beats the file. A replay plays its own seed, and asking for another
  besides is refused.
- **`random` draws four bytes from `/dev/urandom`**, the only random source
  outside the named streams, used once before the match exists and written to
  the seed notebook in the RAM tier.
- **`ticks` is required by the runner**; `./run-headless` says out loud that it
  passes ten thousand, the phase demo's number, when not told otherwise.
- **The unit capacity is a rule** (`units` in the rules), since the runner has
  to allocate a world and nothing in `input/` is about capacities.
- **The wall time is read from the monotonic clock** through the FFI, because
  Lua's clocks are whole seconds or processor time, and the thread pool will
  make processor time run faster than the wall. The sightline seconds are the
  time the sight-and-aim row took, measured by `advance_timed`, a twin of
  `advance` that only reads the clock.
- **`factories` and `shortest_pattern` are zero** until factories and patterns
  exist; the report carries them because the contract table names them.
- `input/field` and `input/players` exist now, each explaining its own shape,
  and `input/what-to-start-with` lists them. `input/players` fixes the number
  of teams and must name both.

## Related documents and tools

- [The views](../../docs/010-the-views.md)
- [The tick and the timers](../../docs/003-the-tick-and-the-timers.md)
- The test program: [the dunes and the clock](../../tests/019-the-dunes-and-the-clock.lua)
- `input/seed`, `input/what-to-start-with`, `output/goodbye`

## Still open

- A2: what ends a match. In this phase nothing does and the tick limit is the
  only stop; the working ruling — the last truck's death — arrives with issue
  210 and the runner's "what ended it" field is where it is reported.
