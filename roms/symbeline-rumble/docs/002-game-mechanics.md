# Game Mechanics

What happens during a match. Meta-progression (between matches) lives in
[`007-units-and-progression.md`](007-units-and-progression.md).

## The board

- **Two tile-pairs.** The map is 2×2 tiles, organized as a left half and a
  right half. Vertical extent is the dominant axis; the player's screen shows
  one half at a time.
- **Spawn structures.** Each side owns at least one structure that emits units
  (barracks, guardhouse). Structures may also be neutral and capturable.
- **Path graph.** Movement is constrained to a pre-authored waypoint graph.
  Units do not freely steer — they consume the path. Encounters resolve in
  place.
- **Resource nodes.** Gemstone mines emit passive gold. Treasure chests sit on
  the map and must be physically returned to a friendly structure by a
  carrying unit before the gold is credited.

## The match clock

Matches do not have a clock. They end when one side no longer has the
structures, units, or gold to continue. The "alive" predicate is:

```
side.alive  ⇔  side.owned_structures > 0  ∧  (side.deck.playable > 0  ∨  side.gold ≥ cheapest_unit_cost)
```

This is enforced in fixed-point integer comparisons — see
[`008-fixed-point-math.md`](008-fixed-point-math.md).

## The economy

- **Gold cap.** Determined by owned structures. Each structure publishes its
  contribution to the cap. Captured structures change the cap immediately.
- **Passive trickle.** Gemstone mines emit gold at a fixed rate per tick.
- **Active retrieval.** A treasure chest contains a fixed amount; the
  carrying unit must reach a friendly structure (any) to deposit. If the
  carrier dies, the gold drops at the death site and is retrievable again.
- **Display.** Gold is rendered as section-marks on a bar attached to the
  nearest owned structure — never as a digit in the corner.

## Units in the match

- **Spawn.** Triggered by player input or structure script. Consumes gold
  from the side's pool.
- **Pathing.** The structure publishes outbound waypoints; the unit walks
  those, with behavior-pattern-influenced branching at decision nodes.
- **Combat.** On encounter (within engagement radius of an enemy), the unit
  enters combat resolution. Combat is microsimmed in fixed-point: each
  participant has hp, atk, def, range, cooldown. Damage applies on tick.
- **Carrying.** Some units pick up treasure-chest gold; carriers move
  slower, do not engage unless engaged.
- **Death.** Removed from the field; pulled from the deck until the deck's
  refresh rule re-enables them.

## The deck

- The deck is the player's playable roster for the match.
- Units enter the deck at match start.
- A dead, on-cooldown, or otherwise unplayable unit is *removed* from the
  cycling deck — not greyed-out — until eligible again.
- Deck refresh rules: timer-based for cooldowns, structure-based for
  resurrects, match-end for permanent death (if permadeath is on; this is
  a meta-progression option per match in a campaign).

## Spell casting

- Spells are cast via the L/R menu of the half they target, OR by
  targeting a friendly unit directly (via touchscreen).
- The original DS hardware cannot tap the top screen; the Anbernic DS can.
  Top-screen targeting is therefore a divergent capability tracked in the
  divergence grid. Casts that need top-screen targeting must have a
  unit-targeted equivalent on baseline DS, or be unavailable there.

## Win condition

A side that fails the `alive` predicate loses. The remaining side wins. No
timed draw — the match runs until someone collapses.
