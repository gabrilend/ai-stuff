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
| **hero unit** | Roughly 2.5× a wave unit's combat weight, carries abilities, obeys sign-posts at junctions, bought with personal resource. |
| **guard** | Spawned by a guard tower. Patrols near its tower instead of walking the lane, and will not leave its leash. |
| **challenge monster** | Very large numbers, walks the center lane, ignores everything a normal soldier would stop for. |

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
| `team` | integer | 1 or 2. |
| `flavour` | integer | 1 wave, 2 hero, 3 guard, 4 monster. |
| `owner` | integer | Player number 1–6 that paid for this body, or **0** if the team spawned it. |
| `archetype` | integer | Row in the unit table: which hero, which monster, which guard. |

### Place

| Field | Type | Meaning |
| --- | --- | --- |
| `lane` | integer | 1–3, or **0** while crossing a connector. |
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
| `upgrade_mask` | integer | Bit set of the upgrades on this body, stamped at spawn. **Always 0 for a hero unit.** |

The mask is stamped **once, at spawn**, and never recomputed. This is the single
most important performance decision in the unit system and it has a design
consequence worth stating plainly: **moving an upgrade out of a lane does not
weaken the soldiers already walking in it.** They keep what they were born with
until they die. Players should be told this outright, because it turns every
reassignment into a decision with a delay, and a delay is what makes a
reassignment worth arguing about.

**Only wave units are ever stamped.** A hero unit's mask is zero and stays zero;
so is a guard's and a monster's. Lane upgrades reach wave units and nothing else.
*Settled; see [open questions](020-open-questions.md), A14.* The reason is that
the two economies must not multiply — if a lane's upgrades also pumped the heroes
standing in it, a team could stack one lane, buy every hero into that lane, and
get a compounding payoff for a decision it made once. See
[the shared upgrade pool](009-the-shared-upgrade-pool.md) for the full argument.

Practically this means step 4 of the swing — walking the mask — is a branch that
is not taken for three of the four flavours, which is worth a comment at the call
site so nobody later "fixes" the apparent inconsistency.

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
