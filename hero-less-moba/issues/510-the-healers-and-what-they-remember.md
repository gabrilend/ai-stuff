# 510 — The Healers, and What They Remember

| | |
| --- | --- |
| Phase | 5 — Commanders and Heroes |
| Blocked by | 203, 204, 504, 509 |
| Blocks | nothing |
| Reads | [standing off and falling back](../docs/022-standing-off-and-falling-back.md) · [hero units](../docs/012-hero-units.md) |
| Open questions | F40 — which of these are wave units and which are heroes |

## Current behavior

Nothing heals. A body that has lost health has lost it for the rest of its life,
and the only support role in the game is a guard tower.

## Intended behavior

Five healers, differing in **shape** rather than strength, each answering the
who-heals-whom problem a different way. The behaviour rules they share — who to
mend, where to stand, and the positional obligation that keeps two healers from
wasting each other — are in
[standing off and falling back](../docs/022-standing-off-and-falling-back.md) and
are not repeated here.

What this issue owes is **the five of them, distinct enough to be worth having.**

| | Heals | Chooses |
| --- | --- | --- |
| **Priest** | one target, slowly and powerfully. Also buffs **fortitude** | soonest to die; fortitude to the most-attacked ally who can still take it |
| **Druid** | one target, as a regeneration ticking up over time — many can run at once, built up one at a time | soonest to die, among those not already regenerating |
| **Paladin** | an **area aura**, plus a periodic minor heal | the minor heal goes to the wounded ally **nearest full whose gap the heal still fills** |
| **Curse-doctor** | allies in **melee range of a cursed enemy** | which *enemy* to curse |
| **Rain shaman** | a **chain** — *chain tide* — bouncing between allies | each bounce prefers the **farthest wounded ally that can fully accept it** |

**"Possibly more, but those are the basic ones."** The five above are the shape of
the roster and not its limit.

### The druid also spikes people with the moon

An ability, and its reason. Kept exactly as it arrived, because the reason is
better than the ability and this project keeps those:

> the druid can also summon a spike of moonlight from their palm which is a
> reflection of the time they spent an entire week gazing upon the unnaterally
> everpresent moon in their astrolabe shrine. It shadows the real moon when it's
> present in the sky, and changes to a rim around it when so. Otherwise it's a
> flat circle that they just conceptualize as the moon, on the other side of the
> planet. They fed themselves entirely with summoned goodberries, and they healed
> all of their wounds gained from staying awake for so long. In the end, they can
> spike their foes with a moon, and they do so sometimes.

Mechanically:

- **A damage-over-time effect**, cast on the **highest-health enemy in line of
  sight**.
- **Allies block line of sight** for this spell.

That last line is the one with teeth, and it should not be quietly dropped for
being inconvenient. It means the druid must have **a clear lane through its own
frontline** to use its one offensive ability — so a druid standing safely behind
a solid rank cannot cast it, and a druid that can cast it is standing somewhere
with a hole in front of it.

**Which makes the frontline queue into a targeting constraint**, and gives a
player something to read: a druid throwing moons is a druid whose line has gaps
in it.

It also aims **opposite to everything else the healers do.** Every healing rule
here reaches for the ally closest to dying; the moon reaches for the enemy
furthest from it. A druid mends what is nearly gone and attacks what is barely
touched — which is a coherent temperament rather than two unrelated buttons.

## Suggested implementation steps

1. Add a **pending-heal buffer** alongside `pending_damage`, cleared every tick
   and resolved in the same pass. Healing must not be a second path into a health
   value; anything that writes health writes through a buffer.
2. Add the **incoming-damage-per-second** figure per body, since the heal target
   rule needs it and the retreat rule in doc 022 needs it too. It is a derived
   number and belongs beside push depth as something maintained rather than
   recomputed.
3. Write the target chooser once, taking the archetype's preference as a
   parameter — soonest-to-die, best-fitting-gap, farthest-that-fits — rather than
   five separate choosers that will drift.
4. Write the **claim** rule: a healer skips a target another healer is already
   healing, and relaxes to fewest-healers-on-them when there are not enough
   wounded to go round. Test the relaxation specifically; it is the branch that
   only fires when the team is winning and will otherwise never be exercised.
5. Write the **positional** rule as a movement goal, not a filter: stay in range
   of at least three valid wounded, out of enemy melee and ranged reach.
6. Write line of sight for the moon spike, with allies as blockers, and a test
   that a druid behind an unbroken rank cannot cast it.
7. Write a scenario (issue 110) with **two healers and three wounded**, arranged
   so one is reachable by each healer and one by both. That is the configuration
   the claim rule exists for, and it should be a file anybody can load and watch.

## Related documents and tools

- [Standing off and falling back](../docs/022-standing-off-and-falling-back.md)
- Issue 504 — the ability dispatch table these are entries in
- Issue 110 — the scenario harness the two-healer case should live in
