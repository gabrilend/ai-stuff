# 112 — Territory is painted on cells

| | |
| --- | --- |
| Phase | 1 — The Dunes and the Clock |
| Blocked by | 102, 104, 106 |
| Blocks | 211, 301, 303, 309, 310, 404, 602 |
| Reads | [territory mass and energy](../../docs/005-territory-mass-and-energy.md) |
| Open questions | B6, C4 |

## Current behavior

Built. `src/039-territory.lua` paints ownership by presence: `claim` marks every
land cell within a radius with its team's bit, `claim_pass` (the tick's sixth
row) marks around every live unit and resolves the marks -- one team alone
claims or keeps claiming, several teams contest and pause the claim -- and
sweeps away claims nobody has stood near for a whole claim length. `owner` and
`percent` read the result. The phase 1 program's direct-claim suites hold; the
original suite still waits for units (issue 201) to stand on the ground.

## Intended behavior

Every land cell has an **owner**: zero, or a team. Water is never owned and the
pass never touches it. Ownership is painted by presence, and a claim in
progress is the [pair of integers](../../docs/003-the-tick-and-the-timers.md) on
the claim counter: each cell holds which team is claiming it and the increment
the claim began at, and the claim completes when enough increments have passed.

The cell's fields, added to the world's layout:

| Field | Type | Holds |
| --- | --- | --- |
| owner | integer | zero, or the team that holds it |
| claiming | integer | zero, or the team whose claim is in progress |
| claim_began | integer | the claim counter's increment when that claim started |
| improvement | integer | reserved for issue 311; zero until then |

`claim(world, team, x, y, radius)` is what one unit does: for every land cell
within the radius, it marks the cell as claimed by the team this tick. It is
the primitive the tests call directly, because this phase has no units.
`claim_pass(world)` walks the live units in array order and calls it with each
unit's team, position, and the claim radius of its kind.

Resolution happens once per pass, over the cells any unit marked:

- **One team present.** If the cell's `claiming` is that team, nothing changes
  and the claim continues; if it is another team or zero, the claim restarts
  for this team at the increment of now. When the increment of now minus
  `claim_began` reaches the claim's length, `owner` becomes the team.
- **Both teams present.** The cell is **contested**: nothing is written, the
  in-progress claim keeps its beginning, and it resumes when one side leaves.
- **Nobody present.** The cell keeps its owner. An in-progress claim with no
  claimer near it for a whole claim length is cleared, so a cell somebody
  walked past does not flip a minute later.

`owner(world, cell)` reads a cell; `percent(world, team)` is the team's owned
land cells over all land cells, as a double, which is the number every economy
rule reads. Everything is deterministic because units are walked in array
order and the resolution reads only what the marks say, never which unit
marked first.

The claim writes shared cell state, so the pass is not sliced. Units are few
and the radius is small, so walking units and not cells is the cheap
direction.

## Suggested implementation steps

1. Claim the file with `./new-source-file --summary "Paints ownership on cells by presence." territory`.
2. Add the cell fields above and a per-tick mark scratch — one integer per
   cell, bits per team — to the world's layout.
3. Write `claim(world, team, x, y, radius)` over the cells in the radius,
   skipping water.
4. Write the resolution as its own folded function over the marked cells, with
   the three cases above as a small dispatch on the mark's value.
5. Write `claim_pass(world)` and add its row to the tick's table in the
   documented position.
6. Write `owner` and `percent`, and the land-cell count computed once at
   assemble.
7. Add the claim counter to the counter table, with its length from the
   catalogue.
8. Fill the companion with the cell's fields.

## What happened

- **The claimant field is `claim_by`, not `claiming`.** Issue 104 laid the cell
  group down with `claim_by` and the tests contract (docs/014) names it, so the
  name stayed; the meaning is the one in the table above.
- **Two more cell fields and a queue.** `claim_seen` (the increment the
  claimant was last near) makes the pause and the clearing possible, and
  `mark` is the per-tick scratch, one bit per team (so at most 30 teams).
  `world.marked`, a queue of cell indices, holds the cells marked this tick in
  the order first marked, so resolution walks only them. Both are empty
  between passes, so a fingerprint never sees half a pass.
- **C4, pause, built as a real pause.** The working ruling said the start
  increment is kept while contested; kept unmoved, the contest's time would
  count and the claim would finish the moment the contest ended. So the start
  moves on by the increments the contest lasted. The ruling's text in
  docs/016 now says this; the question itself stays for Ritz.
- **Walking away pauses too, and a whole length away clears.** Whole
  increments spent away do not count toward the claim; with nobody near for a
  whole claim length, the claim is cleared (the third open point, as the
  working ruling had it).
- **An owner standing alone on its own cell ends another team's claim** on it,
  rather than starting a claim on ground it already holds.
- **The sweep runs on the tick the claim counter fires**, once a claim
  increment, because it walks every cell; resolution runs every tick.
- **Within the radius means centre to centre**, `dx*dx + dy*dy <= r*r`, from
  the cell the unit's position stands in.
- **B6: every unit claims with `claim_radius` from the rules for now.** A
  kind's own radius (the enforcer's four, a plane's none) belongs in the unit
  catalogue, issue 202, and the enforcer's with issue 211.
- **`percent` is from 0 to 100**, as a double, counted on each call (a
  field's land count is counted once and cached). `percent(world, 0)` is the
  land nobody holds.
- No counter was added: the claim counter came with issue 106.

## Related documents and tools

- [Territory, mass, and energy](../../docs/005-territory-mass-and-energy.md)
- [The tick and the timers](../../docs/003-the-tick-and-the-timers.md)
- The test program: [the dunes and the clock](../../tests/019-the-dunes-and-the-clock.lua)

## Still open

- B6: the claim's length in increments and its radius per kind. Working values
  go in the catalogue; the enforcer's larger radius arrives with issue 211.
- C4: whether a contested claim resets or pauses. The working ruling is pause,
  as above.
- Whether an abandoned claim should clear at all, or simply sit until somebody
  returns. Clearing is the working ruling; the proving ground decides.
