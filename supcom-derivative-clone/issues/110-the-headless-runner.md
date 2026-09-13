# 110 — The headless runner

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 102, 105, 109 |
| Blocks | 609, 901, 902 |
| Reads | [the views](../docs/010-the-views.md) |
| Open questions | A2 |

## Current behavior

Nothing. There is no way to run a match. The phase 1 test program looks for a
source file whose stem is `headless-runner` and reports its absence by name;
`./run-tests` and `./compile` exist from issue 101 and would call it if it did.

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

## Related documents and tools

- [The views](../docs/010-the-views.md)
- [The tick and the timers](../docs/003-the-tick-and-the-timers.md)
- The test program: [the dunes and the clock](../tests/019-the-dunes-and-the-clock.lua)
- `input/seed`, `input/what-to-start-with`, `output/goodbye`

## Still open

- A2: what ends a match. In this phase nothing does and the tick limit is the
  only stop; the working ruling — the last truck's death — arrives with issue
  210 and the runner's "what ended it" field is where it is reported.
