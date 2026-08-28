# 502 — Killing Pays Everyone on the Team

| | |
| --- | --- |
| Phase | 5 — Commanders and Heroes |
| Blocked by | 205, 501 |
| Blocks | 503, 505, 803 |
| Reads | [commanders and personal resource](../docs/011-commanders-and-personal-resource.md), [combat and damage](../docs/006-combat-and-damage.md) |
| Open questions | B5, and a new one this rule created |


## Current behavior

Every kill pays every player on the other team, in full, in the colour the dead
body was carrying. Nothing asks what killed it. Teammates therefore have identical
incomes and the only thing separating two of them is what they do with the same money.

Resource is six colours, each with its own shape as well as its own hue, and a wallet
is capped by a die ladder that climbs on the match clock.

## Intended behavior

In the reap pass, `last_hit_by` is read, the killer's **team** is taken, and
**every player on that team is credited the full payout.**

The killer's `owner` field is **not consulted for payment**. It still exists and
still decides who owns a hero for the spawn rules and the post-match report, but
it has nothing to do with who is paid. A wave unit, a tower guard, a guard tower's
arrow, somebody else's hero, or the last blow on a challenge monster all pay
identically.

The payout scales with what was killed: a wave unit is worth a little, a hero a
lot, a challenge monster an enormous amount — the largest single payout in the
game, and worth positioning a hero to collect. The catalogue figure is **per
player**, not a pot divided three ways, so a team's total income is three times
what any one player sees.

**Last hit, not most damage.** The whole chain from issue 205 exists to make that
one field trustworthy.

### What this makes the second economy

Income is identical across a team, so the only thing separating two teammates is
**what they do with the same money**: when to bank, when to spend, which of the
five heroes, and which of the three spawn destinations. That is a better axis to
differentiate players on than who was better at landing final blows, and it means
a player who is inattentive at the frontline is not thereby poorer — only slower
to convert.

It also means the hero economy has **no death spiral**. A player who buys a hero,
puts it somewhere stupid, and loses it in ten seconds has lost the purchase and
nothing else. The word *personal* in personal resource means a private wallet,
not a private income.

## Suggested implementation steps

1. Write the payout into the reap pass, reading the killer's `team` — not its
   `owner`.
2. Put the per-flavour payout figures in the unit catalogue, not in code.
3. Credit every player on the team in one loop over the team-size constant, so
   changing team size does not change the payout each player sees.
4. Track `resource_earned` per player for the post-match report, broken down by
   what was killed — the breakdown is identical across a team, which is itself a
   useful assertion to make in a test.
5. Write the payout as **one function with one call site**, so that a future
   change to who is paid is a change to one function.
6. Write a test: a wave unit kills a wave unit, all three players on the killing
   team are paid, and no player on the other team is.
7. Have the headless runner report each team's income curve against its push
   depths, because the correlation between them is the thing this rule creates
   and nobody has looked at yet.

## Related documents and tools

- [Commanders and personal resource](../docs/011-commanders-and-personal-resource.md)
- [Combat and damage](../docs/006-combat-and-damage.md)

## Settled

**Any kill by your team pays every player on your team, in full.** The killer's
`owner` field is not consulted for payment.

See [combat and damage](../docs/006-combat-and-damage.md) for what that makes the
second economy, and for the rejected alternative — paying only the owner of the
killing body — which carried a death spiral.

## Still open

**A team's income now tracks its map position.** A team winning lanes kills more,
earns more, fields more heroes, and wins lanes harder — the same snowball the
upgrade economy has, running alongside it. Unlike the upgrade economy, nothing
interrupts this one: a siege-surge sweeps the chest into the library but does not touch
anybody's wallet. Whether the hero economy needs a floor, a catch-up term, or
nothing at all is a question this answer created and issue 804 is where it gets
measured.

**Is the catalogue figure per player or a pot divided?** Treated here as per
player. That is a ruling, not part of the answer, and it triples a team's real
income compared with the other reading.

**And the figures themselves**, per flavour of thing killed, are still unchosen.
