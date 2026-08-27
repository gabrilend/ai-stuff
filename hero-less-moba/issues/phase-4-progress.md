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
| 402 | An instance is a thing in a place | built |
| 403 | Wiping a wave draws an upgrade | built |
| 404 | Placing an upgrade into a lane | built |
| 405 | A soldier is stamped at birth | built |
| 408 | Slotting upgrades into stone | built |
| 409 | The base inherits every lane | built |
| 410 | The library slot is the last stand | built |
| 411 | Rerolling the deck | built |
| 412 | Contributing a stone | built, as contribute |
| 413 | Staking a die to share | built, as offer |

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

**402 is built, and it changed the shape of the rest of the phase.** An upgrade is
an instance now — a specific thing, in a specific place, **belonging to somebody** —
and everything that needs to point at one particular stone became possible at once.

**A stone belongs to whoever drew it, and there is no lock**, because there is
nothing to lock it against. That is the design's second answer to the same problem
and it is shaped by the first's failure: locks needed a timeout to tune, an interface
that reminded you what you were holding hostage, and a mechanism whose whole purpose
was doing something to somebody against their wishes.

**Moving takes a wave**, applying at the old slot the whole way, so a placement lands
two waves after the command. That delay is the negotiation layer — without it a team
would simply keep everything wherever the fighting is — and it is a message nobody
opted into: you cannot move a stone quietly, and your teammates get a wave's notice.
Cancelling is free until it lands.

**Contribute, offer and dismiss are in**, which is 412 and 413 arriving under
different names than the roadmap gave them. The floor closes: when everybody has set
the same communal stone aside it comes back to all of them, so a stone cannot fall
through neglect. **Request** is in and is deliberately the weakest verb — it changes
nothing, only one can stand at a time, and ignoring one is free and silent.

**411 is built.** A reroll trades a stone for the next card, priced in two colours,
and it is the only thing personal resource can do to the chest.

**Not built:** chat, which is issue 806 and belongs to phase 8; and the interface for
offering to a *specific* teammate, which needs a way to name one and has no
single-player meaning yet.

**One deviation from the written design**, raised as G6: the modifiers are folded
into a body's fields at stamp time rather than walked on every swing. Identical
numbers, one multiplication per body instead of one per blow. It is safe only
because of a rule the design already committed to, and the documents and the code
should be made to agree about which one they describe.
