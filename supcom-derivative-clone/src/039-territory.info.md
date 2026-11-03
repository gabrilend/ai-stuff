# 039-territory

Paints ownership on cells by presence.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

Every land cell has an **owner**: zero, or a team. A team takes a cell by
standing near it, alone, for long enough. "Long enough" is a count of
increments on the claim counter (`world.claim`), so a claim in progress is the
[pair of integers](../docs/003-the-tick-and-the-timers.md): which team is
claiming, and the increment the claim counts from. Water is never marked, so it
is never claimed and never owned. Everything in the economy reads `percent`.

A pass has two halves:

1. **Marking.** Each live unit, in array order, sets its team's bit on every
   land cell within its radius; a cell's first mark also pushes it onto the
   `marked` queue.
2. **Resolving.** Each marked cell, in the order first marked, is decided by
   its bits alone -- never by which unit marked first -- so the outcome does not
   depend on the order of the units:

| Mark | What happens |
| --- | --- |
| one team, which owns the cell | any other team's claim on it ends |
| one team, whose claim it is | the claim goes on; whole increments it spent away from the cell are not counted; it completes when the increment of now minus `claim_began` reaches `increments_to_claim` |
| one team, someone else's claim or none | a claim starts for this team at the increment of now |
| several teams | contested: nothing changes hands and no claim starts; a claim whose claimant is among them is **paused**, its beginning moved on by the increments the contest lasted |

Once every claim increment (on the tick the counter fires), a **sweep** clears
every claim whose claimant has not been near its cell for a whole claim length,
so a cell somebody walked past does not flip a minute later.

The claim writes shared cell state, so its row in the tick is not sliced.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `claim(world, team, x, y, radius)` | a world; a team from 1; a position in cells; a radius in cells, from zero | nothing; marks every land cell whose centre is within `radius` of the cell the position stands in. The primitive the tests call directly |
| `claim_pass(world)` | a world | nothing; the tick's `claim` row: brings the claim counter up to the tick, marks around every live unit with the rules' `claim_radius`, resolves, and sweeps on the tick the counter fires |
| `owner(world, cell)` | a world; a cell index | zero, or the team holding it; raises on an index off the field |
| `percent(world, team)` | a world; a team, or zero for nobody | the team's owned land cells over all land cells, from 0 to 100, as a double |
| `land(world)` | a world | how many land cells its field has, counted once per field |
| `TEAMS` | | 30, the most teams a mark can hold |

## Data structures it owns

The cell fields it writes, in `world.cell` (laid out by `the-world`):

| Field | Holds |
| --- | --- |
| `owner` | zero, or the team that holds the cell |
| `claim_by` | zero, or the team whose claim is in progress |
| `claim_began` | the increment the claim counts from: when it began, moved on by any increments it spent paused |
| `claim_seen` | the increment its claimant was last near the cell |
| `mark` | this tick's presence, bit `team - 1` per team; zero between passes |

And `world.marked`, a queue of cell indices with the field's area as its
capacity: the cells marked this tick, emptied by the resolution. Between passes
both are empty, so a fingerprint never sees them half-done.

A kind's own claim radius (the enforcer's larger one, a plane's none) arrives
with the unit catalogue; until then every unit claims with `claim_radius` from
the rules.
