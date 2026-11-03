# 037-headless-runner

Plays a match with no window and reports.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

The simulation run end to end: the first program that does it, what the tests
drive, what the overnight runs will be, and what the phase 1 demo is. The root
script `./run-headless` is its front door.

`run(root, options)` does, in order:

1. **Reads `input/` first**: the seed (`input/seed`), the field's shape
   (`input/field`), the players (`input/players`, which fix how many teams).
   A malformed line is refused by its file and line number, a missing field
   parameter by its name.
2. Chooses the seed: the environment's `SDC_SEED` beats `options.seed`, which
   beats `input/seed`. `random` there draws four bytes from `/dev/urandom` and
   appends the seed to `seeds.log` in the RAM tier; a typed seed is never logged.
3. Assembles the world through the tick, with the rules' `units` as the unit
   capacity unless `options.units` gives one.
4. Records a replay log at `/dev/shm/<project>/replays/seed-<seed>.log`.
5. Advances the tick until `options.ticks` or until the tick says the match
   ended, timing every row.
6. **Writes `output/goodbye` last**, the report in lines.

Given `options.replay`, it reads that log instead of recording one, plays the
log's seed, refuses a log whose stamp differs from the match it would make,
queues the log's commands, and after every tick compares the fingerprint the
world took with the log's hash for that tick. The first difference stops the
play and is reported by its tick. With no `ticks` given, a replay runs to just
past the last tick its log holds.

Nothing here draws; the caller hands `report.world` to a viewer as a copy.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `run(root, options)` | the project root; options below | the report below |
| `lines(report)` | a report | its fields as `name: value` lines, in `REPORT` order, the hash in hex |
| `REPORT` | | the order `lines` writes |

Options: `ticks` (a whole number, required unless replaying), `seed`, `field`
(a shape table beating `input/field`), `units`, `fingerprint_every` (ticks
between fingerprints, beating the rules'; one narrows a desync to its exact
tick), `replay` (a log's path; a replay always fingerprints at the interval its
log was recorded at, and refuses a different one asked for), `workers` (how
many ranges the thread pool slices a sliceable row into, beating
`input/workers`, which is a number or `cores`; the answer is the same at any
count), `bots` (reserved for issue 901; nothing reads it yet).
`./run-headless --fingerprint-every N` and `--workers N` pass them through.

## Data structures it owns

The report:

| Field | Holds |
| --- | --- |
| `seed` | the seed the match was raised from |
| `ticks` | ticks run |
| `hash` | the final world's fingerprint |
| `ended` | what stopped it: `the tick limit`, `the match ended`, or `a mismatch with the replay at tick N` |
| `wall_seconds` | seconds on the monotonic clock, start to finish |
| `sightline_questions`, `sightline_seconds` | how many sightlines were asked, and the seconds the sight-and-aim row took |
| `system_seconds` | every row's processor seconds, by name |
| `replay` | where the log was written; empty when replaying |
| `replay_checked`, `mismatch_tick` | when replaying: hashes compared, and the first tick that differed (zero for none) |
| `factories`, `shortest_pattern` | zero until factories and patterns exist (issues 307 and 308) |
| `workers` | the thread pool's worker count for the match (issue 209) |
| `world` | the final world, for a viewer to copy |

The input files' shapes are written at the top of each file in `input/`.
