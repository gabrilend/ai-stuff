# 902 — Ten thousand matches overnight

| | |
| --- | --- |
| Phase | 9 — An Opponent |
| Blocked by | 110, 901 |
| Blocks | — |
| Reads | [roadmap](../docs/015-roadmap.md) |
| Open questions | none |

## Current behavior

Nothing. The headless runner (issue 110) plays one match with no window and
prints a report. The balance ledger in `docs/` is empty because nothing has
run, and every number in the catalogue is the vision's first guess. There is
no way to find out whether a ridge route beats a trough route, whether the
four energy levels are ever all worth choosing, or how long a match lasts,
except by watching one.

## Intended behavior

A script at the project root plays a great many matches with nobody watching
and prints the table you read in the morning. It reads `input/` for how many
matches, which bots, and the field's shape; it takes a seed per match from a
named stream off one base seed so the whole night is reproducible; and it runs
**one worker per core**, each a headless runner process, because a night of
matches on one core is a week.

Each match writes **one line** to a log in the RAM tier —
`tmp/shared-memory/matches/` — with the seed, the final tick, which team held
more ground and how much, the truck that died if one did, the final hash, and
how long the match took to compute. A line per match and nothing else, so the
log is a table already, and a match that crashed writes its error on its line
rather than leaving a gap.

A second, separate program reads the log and produces the summary: win rate by
team, the distribution of match lengths, how often each energy level was
chosen, how much ground changed hands per match, and the hash of the same seed
across workers — which must be one value, and is the reproducibility test at
scale. The two programs are separate on purpose: generate, then view. The
summary is what the balance ledger's entries cite.

## Suggested implementation steps

1. Write `run-many-matches` at the project root, in the shape of every other
   script here: a hard-coded `DIR`, an override argument, `input/` read first,
   `output/goodbye` written last.
2. Add a `--seed` and `--line` form to the headless runner so a worker can be
   told one seed and asked for one line of output.
3. Write the worker fan-out: one runner process per core, each handed a slice
   of the seed list, each appending to its own log file so no two workers share
   a file.
4. Write the summary program as a numbered source file that reads every log
   file in the directory and prints the tables above; nothing in it plays a
   match.
5. Run a hundred first, read the summary, and only then a night's worth.
6. Cite the first summary in the balance ledger's first entry, whatever it
   changes.

## Related documents and tools

- [Roadmap](../docs/015-roadmap.md) — phase 9
- [The shape of the code](../docs/013-the-shape-of-the-code.md) — scripts, and
  generate-then-view
- [Balance updates](../docs/balance-updates.md) — where the summary's findings go
- `tests/027-an-opponent.lua`

## Still open

- Whether the workers should be processes or the thread pool from issue 209.
  Processes are the working answer: a match is already sliced across the pool
  inside one runner, and a night of matches wants isolation more than it wants
  shared memory.
- What a match's "length" means when the truck rule (A2) is open: the tick a
  truck died, or the tick the ground stopped changing hands.
