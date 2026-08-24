# 006 — Combat and Damage

**Datapath document.** Covers what happens between "this soldier swings" and
"that soldier is dead," and how an upgrade sitting in a lane turns into a larger
number on a specific blow.

## Damage is buffered, then applied

Nothing writes to a health value during the attack pass. Attacks write into
`pending_damage`, a flat array of doubles with one slot per soldier and one per
structure, cleared at the top of every tick. A separate resolve pass adds the
buffer into health and marks anything at or below zero as dying.

The reason is simultaneity. Two soldiers on their last sliver of health, both off
cooldown on the same tick, should both die. If damage were applied immediately,
whichever one the loop happened to reach first would win, and which one that is
depends on slot ordering — which depends on which soldier died four minutes ago
and freed its slot. That is a real, reproducible, completely unexplainable
unfairness, and buffering removes it.

It also makes the attack pass safe to slice across the thread pool: every worker
writes into distinct slots of a preallocated array and reads nothing another
worker is writing.

## One swing, start to finish

1. **Cooldown.** `cooldown` is decremented. If it is above zero, done.
2. **Range.** Straight-line distance from attacker to target compared against
   `range`. This is the *only* place in the game that uses as-the-crow-flies
   distance; everything about progress and lanes uses milestones.
3. **Base damage.** The attacker's `damage`.
4. **Upgrades.** The attacker's `upgrade_mask` is walked and each set bit's
   modifier is applied, additive terms first, then multiplicative. The mask was
   stamped at spawn and is not re-read from the lane, so the arithmetic is a
   handful of table lookups with no pointer chasing back into team state.
5. **Armour.** The defender's `armour` is subtracted, and the result is floored
   at a small positive minimum so that a heavily upgraded defender is very hard
   to kill but never literally immune. Immunity in a lane-pusher means a
   permanent stalemate, which is the exact failure this whole game is built to
   avoid.
6. **Write.** The result is added into `pending_damage[target]`, and the
   attacker's id is written into `last_hit_by[target]`, overwriting whatever was
   there. Last hit, not most damage, decides who gets paid.
7. **Reset.** `cooldown` is set to `cooldown_max`.

## Kill attribution

When the resolve pass finds a soldier at zero health it reads `last_hit_by`,
identifies the killer's **team**, and pays **every player on that team**.
*Settled; see [open questions](020-open-questions.md), A2.*

It does not matter what killed it. A wave unit, a tower guard, a guard tower's
arrow, a hero unit, a challenge monster — every kill your team lands pays every
player on your team the full listed amount. The killer's `owner` field is **not**
consulted for payment. It still exists, and it still decides who owns a hero for
the purposes of the spawn rules and the post-match report, but it has nothing to
do with who is paid.

Three consequences worth stating outright, because they shape how the second
economy feels:

1. **Nobody can be locked out.** A player who spends everything on a hero and
   loses it badly keeps earning at exactly the same rate as their teammates. The
   hero economy has no death spiral in it.
2. **Teammates have identical incomes.** The only difference between two players
   on the same team is *timing and choice* — when to bank, when to spend, and
   which hero. That is a cleaner axis than "who farmed better," and it means a
   player who is bad at last-hitting is not thereby a worse teammate.
3. **The team's income tracks the team's map position.** A team winning lanes is
   killing more, so it earns more, so it fields more heroes, so it wins lanes
   harder. This is the *same* snowball the upgrade economy has, running in
   parallel — and the siege-surge does nothing about this one. Whether that needs
   a floor is a new open question, raised by this answer.

## Where abilities fit

A hero's abilities are entries in an **ability dispatch table**: an array of
functions indexed by ability id, each taking the world, the caster, and the
target, and each writing into the same `pending_damage` buffer that a normal
swing does. Abilities are not a parallel damage system. Anything an ability can
do to a health value, it does through the buffer, on the same tick boundary, with
the same armour arithmetic.

Abilities fire automatically when their conditions are met and their cooldown is
ready. There is no cast button and no targeting cursor, and **there is no manual
control over a hero of any kind** — no hold-position, no focus-this, no
triggerable ability. *Settled; see [open questions](020-open-questions.md), D2.*
A hero is a soldier you paid for and pointed, not a puppet you drive, and that
rule is what keeps the soldier brain the only brain in the game.

The design consequence lands here rather than in the hero document: since nothing
can intervene, an ability's **condition** carries all the weight. Conditions are
their own dispatch table, so an ability is a (condition, effect, cooldown) triple
assembled from two tables, and two heroes with identical stats and different
conditions are two genuinely different purchases.

## Structures take damage the same way

A guard tower and a library have `health` and are addressed through the same
buffer, indexed into the structure half of the array. They have no armour and
take full damage, which keeps siege maths simple: the number of soldier-swings
needed to fell a tower is a number a player can hold in their head.

Related: [a unit and what it carries](004-a-unit-and-what-it-carries.md) ·
[the simulation tick](003-the-simulation-tick.md) ·
[guard towers](007-guard-towers-and-their-guards.md) ·
[the shared upgrade pool](009-the-shared-upgrade-pool.md)
