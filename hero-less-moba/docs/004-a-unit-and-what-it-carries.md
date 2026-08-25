# 004 — A Unit and What It Carries

**Datapath document.** Covers the only actor in the game: the soldier. What is
stored about one, how it decides what to do, and why heroes, guards, and
challenge monsters are all the same thing with different numbers.

## There is one kind of body

The vision is blunt about it: hero units "behave like regular units so we better
make sure that our unit AI is top notch." That is taken literally. There is one
soldier record, one movement routine, one targeting routine, one attack routine.
The four flavours differ only in the values in their fields:

| Flavour | How it differs |
| --- | --- |
| **wave unit** | The baseline. Ability slot empty. Spawned by wave or surge timers. |
| **hero unit** | Roughly 2.5× a wave unit's combat weight, carries abilities, obeys **one** sign-post in its life and then goes straight on forever after, bought with personal resource. |
| **guard** | Spawned by a guard tower. Patrols near its tower instead of walking the lane, and will not leave its leash. |
| **challenge monster** | Very large numbers, walks the centre lane, ignores everything a normal soldier would stop for. On its own third team, hostile to both sides, and assigned to whichever team it is a test for. |

Having one body type is a design constraint with teeth: any behaviour worth
giving a hero has to be expressible as a field on the common record, which keeps
the brain small enough to actually be good. The alternative — a separate hero
controller — is how lane-pushers end up with soldiers that are visibly stupider
than heroes, and in a game with no heroes at the centre of it, visibly stupid
soldiers are the whole product.

## The record

Stored as parallel flat arrays indexed by soldier id, not as a table per soldier.
The grouping below is how the fields cluster in the tick, which is also how they
cluster in memory.

### Identity

| Field | Type | Meaning |
| --- | --- | --- |
| `alive` | integer | 1 or 0. Dead slots are reused; ids are recycled with a generation counter. |
| `generation` | integer | Bumped each time a slot is reused, so a stale id can be detected instead of pointing at a stranger. |
| `team` | integer | 1 or 2 — or **3**, the monsters' team, which is allied with nobody and hostile to everything. *See F13.* |
| `flavour` | integer | 1 wave, 2 hero, 3 guard, 4 monster. |
| `owner` | integer | Player number that paid for this body, or **0** if the team spawned it. Numbers run 1 to twice the team size; six is not a constant. *See F10.* |
| `archetype` | integer | Row in the unit table: which hero, which monster, which guard. |

### Place

| Field | Type | Meaning |
| --- | --- | --- |
| `lane` | integer | 1 to the lane count, or **0** while crossing a connector. |
| `node_from`, `node_to` | integer | The edge currently being walked. |
| `progress` | double | 0 to 1 along that edge. |
| `x`, `y` | double | Derived each move pass from the above. The renderer reads these; nothing else does. |
| `facing` | integer | +1 toward team 2's base, −1 toward team 1's. Guards use 0 while patrolling. |
| `milestone` | integer | Deepest milestone index this body has reached. Feeds the team's push depth. |

### Body

| Field | Type | Meaning |
| --- | --- | --- |
| `health`, `health_max` | double | Current and full. |
| `damage` | double | Per swing, before upgrades. |
| `armour` | double | Flat subtraction, floored so a hit never heals. |
| `range` | double | In paces. Melee is a small nonzero number, not a special case. |
| `speed` | double | Paces per tick. |
| `cooldown`, `cooldown_max` | integer | Ticks until the next swing is allowed. |

### Mind

| Field | Type | Meaning |
| --- | --- | --- |
| `state` | integer | 1 walking, 2 closing, 3 fighting, 4 leashing home, 5 dying. |
| `target` | integer | Soldier id, or **0** for none. Structures are targeted through a separate field. |
| `target_structure` | integer | Structure id, or **0**. |
| `target_generation` | integer | Checked against the target's generation before every use. |
| `leash_node` | integer | The node a guard must not stray far from. **0** for everything else. |
| `ability_cooldown` | integer[2] | Ticks remaining on each of up to two abilities. |

### Modifiers

| Field | Type | Meaning |
| --- | --- | --- |
| `upgrade_count` | integer[kinds] | How many copies of each catalogue kind this body carries. One small integer per kind, not a bit set — duplicates stack, and a bit set cannot count. *See [open questions](020-open-questions.md), F3.* |

**What is in that vector depends entirely on the flavour**, and the four cases
are genuinely different from each other. This table is the whole of it:

| Flavour | Its lane's upgrades | Its tower's upgrades | Boons |
| --- | --- | --- | --- |
| **wave unit** | **stamped at spawn**, from the lane it was spawned for | — | yes |
| **hero unit** | **never, at any strength** | — | yes |
| **guard** | — | **read live through its tower**, never stamped | yes |
| **challenge monster** | never | — | **no** — it is on nobody's team |

Three rules are packed in there and each needs its own comment at the call site,
because each of them looks like an inconsistency to somebody fixing the others.

**Wave units are stamped once, at spawn, and never recomputed.** This is the
single most important performance decision in the unit system, and it has a
design consequence worth stating plainly: **moving an upgrade out of a lane does
not weaken the soldiers already walking in it.** They keep what they were born
with until they die. Players should be told this outright, because it turns every
reassignment into a decision with a delay, and a delay is what makes a
reassignment worth arguing about.

**Guards are the exception, and they read live.** *See F1.* A guard carries
whatever is slotted into its own tower at this instant — gaining it the moment it
arrives and losing it the moment it leaves. It is the only place in the combat
loop where a body's modifiers are a lookup rather than a copy, and the reason is
that a guard belongs to something that stands still for the whole match: reading
through costs one indirection and buys the ability to change your mind. Note also
that a lane's tower slot delivers **melee** upgrades to the guards and **ranged**
upgrades to the tower, with common ones going to both — see F21.

**Lane upgrades never touch heroes.** *See A14.* A hero walking through a lane
stacked with every upgrade the team owns fights at exactly its catalogue values,
because the two economies must not multiply: if a lane's upgrades also pumped the
heroes standing in it, a team could stack one lane, buy every hero into it, and
compound a decision it only had to make once.

**Boons are the thing that reaches everybody.** *See F4.* They are not in a lane
and have no slot, so there is no placement decision for them to multiply with —
which is exactly why they are allowed where a lane upgrade is not. A boon is best
understood as a modifier on the commander that radiates out to everything that
team fields, heroes included. Monsters get none, having no team to belong to.

## The brain

The state field indexes a **dispatch table of behaviour functions**, one per
state, each returning the next state. There is no chain of conditionals deciding
what a soldier is doing; the soldier already knows, and the table says what
knowing that means.

**Walking.** Advance along the lane. Each tick, ask whether anything hostile is
within *acquisition range* — a radius wider than weapon range, so soldiers commit
to a fight slightly before they can hit. If yes, take a target and go to closing.
If the next node carries an enemy structure and no enemy soldier is nearer, take
the structure as a target.

**Closing.** Keep advancing toward the target until it is inside weapon range,
then go to fighting. Recheck the target's generation every tick; if it died,
drop back to walking rather than walking into empty air.

**Fighting.** Stop. Swing when the cooldown allows. Heroes check their ability
cooldowns here. If the target dies, go back to walking on the same tick rather
than idling for one — an idle tick per kill is invisible individually and adds up
to a visibly limp frontline.

**Leashing.** Guards only. Walk back toward the leash node, refusing to acquire
anything on the way.

**Dying.** One tick of bookkeeping: pay every player on the killer's team, decrement the wave's
living count, free the slot.

### Choosing a target

Ranked, cheapest test first, ties broken by the `tie` random stream so that two
identical soldiers do not both pick the leftmost enemy every single time:

1. An enemy soldier already attacking me.
2. The nearest enemy soldier within acquisition range.
3. An enemy structure within weapon range.
4. Nothing — keep walking.

Structures rank below soldiers deliberately. A soldier that walks past a
defended tower to chew on the tower is a soldier that dies for free, and a
frontline made of those never moves.

## Forming a frontline

Soldiers do not overlap and do not push each other. When a soldier in the
closing state would end its move inside the personal space of a friendly soldier
ahead of it, it stops short instead. The result is a queue: the front rank
fights, the ranks behind stack up along the lane and step forward as the front
rank dies. This is what makes a wave read as a *wave* rather than a smear, and
it is what makes a lane upgrade legible — a stronger front rank visibly holds
its ground while the enemy queue backs up.

Related: [the map](002-the-map-and-its-milestones.md) ·
[combat and damage](006-combat-and-damage.md) ·
[waves](005-waves-and-when-one-is-finished.md) ·
[hero units](012-hero-units.md)
