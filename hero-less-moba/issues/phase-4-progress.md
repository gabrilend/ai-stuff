# Phase 4 Progress — The Shared Chest

**The goal:** the centre of the game. Upgrades, the deck they come from, the
lanes and stone they go into, and the negotiation between three people sharing
one chest. This is what replaced heroes, and it is the phase that has to justify
the premise.

**Ends with:** the phase-2 stalemate broken. The same two waves, but one lane's
soldiers carrying three upgrades, and the frontline moving.

| Issue | | Status |
| --- | --- | --- |
| 401 | The upgrade catalogue | built |
| 402 | An instance is a thing in a place | counts, not instances |
| 403 | Wiping a wave draws an upgrade | built |
| 404 | Placing an upgrade into a lane | built |
| 405 | A soldier is stamped at birth | built |
| 408 | Slotting upgrades into stone | built |
| 409 | The base inherits every lane | built |
| 410 | The library slot is the last stand | built |
| 411 | Rerolling the deck | not started |
| 412 | Contributing a stone | not started |
| 413 | Staking a die to share | not started |

**Blocking:** nothing.

**Carry into the work — this phase changed the most after it was drafted:**

- **One deck, both teams, same order.** There is no per-team draw randomness. A
  team killing more is *further along the same track*, which removes the last
  source of asymmetry that is not a decision — and makes the enemy's chest
  legible without an interface, because it is your own from two minutes ago.
- **Moving an upgrade takes one full wave**, applying at its old slot meanwhile.
  That replaces the reassignment cooldown entirely; **do not build one.** A
  transit is visible to teammates the whole time and can be cancelled freely
  until it lands.
- **Rerolling** (issue 411) is the only exchange between the two economies. You
  pay into the dark — the next card is not shown.
- **Nothing may be placed during a surge**, and every chest command is refused.
- **Locking is unlimited and free.** No counter to enforce; the interface just
  owes a player a visible count of what they hold locked.
- **Upgrades never touch heroes.** Enforce it in the catalogue's structure, not
  by remembering.

**Still open:** A16c (a flat reroll price against a rising ceiling gets cheaper
over a match — a curve nobody chose), A11b-iii and C3 (the hero economy's
unbraked snowball), B3 and B7 (numbers).

**Demo:** not yet built. **This one is the proof the design rests on.**

## Where the prototype got to

The phase's ending is reproduced, and it is the most important measurement the
project has taken so far.

**The stalemate breaks.** From one seed: an untouched match leaves both teams
between milestones three and four in every lane, indefinitely. The same seed, with
one team shovelling everything it draws into the centre lane, takes that lane to
milestone **8** — the enemy library — while the enemy's depth in it collapses to
**0**, with the other two lanes unchanged as a control. Recorded against B11.

The chest, the shared deck, the draws, the three kinds of slot, and the stamp a
body takes at birth are all standing. So is the rule that makes the whole thing
worth arguing about: **a wave unit is stamped once and never corrected**, so moving
an upgrade out of a lane does not weaken the soldiers already walking in it, while a
guard *is* re-stamped, because it stands under the thing it copied from for its
whole life.

**402 is approximate.** Upgrades are counts per kind rather than instances with
identities, which is enough for placing, recalling, and stamping, and is not enough
for anything that needs to point at one particular upgrade — a lock, an objection, a
transit mark. 411, 412 and 413 are not started for the same reason.

**One deviation from the written design**, raised as G6: the modifiers are folded
into a body's fields at stamp time rather than walked on every swing. Identical
numbers, one multiplication per body instead of one per blow. It is safe only
because of a rule the design already committed to, and the documents and the code
should be made to agree about which one they describe.
