# 901 — A bot that lays lines and draws patterns

| | |
| --- | --- |
| Phase | 9 — An Opponent |
| Blocked by | 110, 308 |
| Blocks | 902, 903 |
| Reads | [roadmap](../docs/015-roadmap.md) |
| Open questions | none |

## Current behavior

Nothing plays the game but a person. The headless runner (issue 110) advances a
world with no commands in it, and a factory placed by hand (issue 308) runs its
line down the pattern it was given. `tests/027-an-opponent.lua` looks for a
`the-bot` stem with `think(snapshot, team)` returning a list of commands, and
asserts two things: the bot is given a snapshot and nothing else, and every
command it returns goes through the door.

## Intended behavior

A bot is a function from a **snapshot** to **commands**, and that sentence is
the whole of its access. It never holds the world. It never calls a simulation
function. What it sees is the same copy a viewer reads, and what it does leaves
through the same door a person's commands leave through, stamped for the same
later tick. It cannot cheat because there is no path by which it could.

This issue builds **the measuring bot**: cheap, deterministic, and dull on
purpose, because its job is to play ten thousand matches overnight (issue 902)
and produce numbers about the rules, not to be interesting. Its decisions are a
**dispatch table** over a small set of situations read off the snapshot — how
much ground is held, how full the roster is, where the nearest enemy-held cell
is, whether a factory of each domain exists — and each row is a rule with no
memory between ticks:

- with no factory of a domain and mass to spare, place one on a held cell
  nearest the frontier and draw its pattern
- a pattern is a straight run toward the nearest enemy-held cell, bent to
  follow the lowest ground between here and there — the trough, because the
  measuring bot should be predictable and a trough is the route a cautious
  player draws
- the energy level is chosen by the ratio of energy to mass held, thresholds
  from the catalogue
- the truck's plane is launched toward the nearest enemy-held cell whenever
  the launch counter allows

Every choice that needs a random draw takes it from a named stream — `bot` —
so two bots on the same seed make the same choices, and the reproducibility
test holds with bots behind both teams.

The opponent worth playing against is a **different program** with the same
access (issue 903), kept apart from this one so that neither is tuned for the
other's job.

## Suggested implementation steps

1. Claim `the-bot`. Exports: `think(snapshot, team)` returning commands, and
   `SITUATIONS`, the dispatch table, as data.
2. Write the snapshot readers the rules need — held-cell count, roster counts,
   nearest enemy cell by array walk — as functions over the snapshot only.
3. Write the trough-following pattern drawer: a straight run of points from the
   factory toward the target, each point moved to the lowest cell within a
   small radius of the straight line.
4. Write the rules as rows, each a function from the situation to a command or
   to nothing, and `think` as the walk over the rows.
5. Hook the bot into the headless runner behind a line in `input/` naming which
   teams are played by it, calling `think` on the snapshot and scheduling what
   comes back.
6. Test: bots behind both teams, one seed, two runs, one hash.

## Related documents and tools

- [Roadmap](../docs/015-roadmap.md) — phase 9
- [Other players](../docs/011-other-players.md) — why the bot cannot cheat
- [The views](../docs/010-the-views.md) — the snapshot the bot shares with a viewer
- `tests/027-an-opponent.lua`

## Still open

- Whether the snapshot handed to a bot — or a viewer — is the whole world or
  only what the team's own eyes can see. The design has no fog system, and
  sightlines decide firing rather than knowledge; but a bot that reads the
  enemy's roster off the snapshot knows something a person watching the screen
  might not. If the snapshot is ever narrowed per team, it is narrowed for both.
