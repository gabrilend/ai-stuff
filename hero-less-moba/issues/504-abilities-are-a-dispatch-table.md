# 504 — Abilities Are a Dispatch Table

| | |
| --- | --- |
| Phase | 5 — Commanders and Heroes |
| Blocked by | 203, 205, 503 |
| Blocks | 509 |
| Reads | [hero units](../docs/012-hero-units.md), [combat and damage](../docs/006-combat-and-damage.md) |
| Open questions | none |

## Current behavior

Heroes are wave units with bigger numbers. Nothing distinguishes one hero from
another except how much health it has.

## Intended behavior

Each hero carries one or two **abilities**. An ability is an entry in a dispatch
table: a function of (world, caster, target) that fires automatically when its
cooldown is ready and its condition is met.

**There is no cast key and no targeting cursor.** The vision's line that heroes
"behave like regular units" is taken as binding: a hero is a soldier you pointed,
not a puppet you drive. A player's hands are busy with the chest; a hero that
demanded attention would compete with the thing that replaced heroes in the first
place.

An ability writes into the **same pending-damage buffer** as an ordinary swing,
resolves on the same tick boundary, and passes through the same armour
arithmetic. There is no second damage system anywhere in this project, and this
is the place someone will most want to add one. Say so in the comment.

An ability's **condition** is a small predicate — target below a health fraction,
three or more enemies within a radius, self below a health fraction, a structure
in range. Conditions are also a dispatch table, so that an ability is a
(condition, effect, cooldown) triple assembled from two tables rather than a
bespoke function per hero.

The three jobs a roster should cover, from issue 509, are best expressed through
abilities rather than through stats: something that holds a frontline, something
that kills a frontline, something that kills stone.

## Suggested implementation steps

1. Write the ability table and the condition table, both indexed by integer.
2. Add `ability[2]` and `ability_cooldown[2]` to the soldier record — zeros for
   anything that is not a hero.
3. Fire abilities in the **fighting** state, before the ordinary swing, so an
   ability that kills the target does not waste a swing on a corpse.
4. Write three real abilities exercising three shapes: a direct hit, an area
   effect, and a self-buff. A mechanism with one example is not a mechanism.
5. Write a test per ability asserting the condition fires when it should and not
   when it should not.
6. Write a test that an ability's damage goes through armour exactly as a swing
   does.

## Related documents and tools

- [Hero units](../docs/012-hero-units.md)
- [Combat and damage](../docs/006-combat-and-damage.md)

## Settled

**Players get no manual control over a hero. None.** No hold-position, no
focus-this, no triggerable ability. The only influence left after a purchase is a
sign-post at a junction the hero has not reached.

Settling it that strictly makes this issue **considerably more important than its
position on the roadmap suggests**: with nothing able to intervene, a hero's
entire personality is its ability *conditions*. Two heroes with identical stats
and different predicates are two different purchases; two heroes with different
stats and the same predicate are the same purchase at two prices.

So the condition table must not be three entries deep. A starting set worth
having:

- target below a health fraction — a finisher
- three or more enemies within a radius — a wave-breaker
- self below a health fraction — a survival trigger
- an enemy structure in range — a siege trigger
- no enemy within acquisition range — a travelling trigger, for anything that
  should happen while walking rather than while fighting
- an ally within a radius below a health fraction — the only support hook, and
  the only one that makes a hero care about the bodies around it

The last two make a hero read as having judgement rather than a bigger number,
and both are cheap: already-computed values from the retarget pass.

See [hero units](../docs/012-hero-units.md) and
[combat and damage](../docs/006-combat-and-damage.md).

## Still open

Nothing blocking. The ability **effects** are open-ended by design; the
constraint that matters is that every one of them writes into the same
pending-damage buffer as an ordinary swing, on the same tick boundary, through
the same armour arithmetic.
