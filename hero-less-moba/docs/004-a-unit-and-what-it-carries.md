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
| **wave unit** | The baseline. Ability slot empty. Spawned by wave or surge timers. **Three archetypes** — see below. |
| **hero unit** | Roughly 2.5× a wave unit's combat weight, carries abilities, obeys **one** sign-post in its life and then goes straight on forever after, bought with personal resource. |
| **guard** | Spawned by a guard tower. Patrols near its tower instead of walking the lane, and will not leave its leash. |
| **challenge monster** | Very large numbers, walks the centre lane, ignores everything a normal soldier would stop for. On its own third team, hostile to both sides, and assigned to whichever team it is a test for. |

### A wave is three kinds of body

`flavour = 1` covers three archetypes, and a wave contains all of them.
*Settled; see [open questions](020-open-questions.md), F22.*

| | Health | Damage | Reach |
| --- | --- | --- | --- |
| **melee** | 1× | 1× | a small nonzero number |
| **ranged** | 1× | 1× | stands off |
| **captain** | **2.5×** | **1.5×** | melee *or* ranged, depending on the captain |

All three are ordinary wave units with different rows in the unit catalogue, all
three spawn with the wave, and **all three are stamped with the lane's
upgrades** — which is what separates a captain from a hero. A hero is roughly
2.5× combat weight with abilities and **no lane upgrades, ever**. A captain is
2.5× health and 1.5× damage *plus* everything sitting in its lane.

So in a lane carrying a dozen upgrades the captain walking out of it is enormous
and the hero beside it is not. That is not an oversight — it is the chest economy
out-scaling the wallet economy in a lane somebody committed to, which is the
right relationship, since the chest is the slow accumulating layer and should win
a long game. What a hero brings instead is **abilities and timing**: it arrives
where and when you choose, and does something a wave unit cannot do at all.

The reach difference is the part with teeth. **Ranged bodies stop further back
than melee bodies**, which the frontline queue at the end of this document was
not written for. See issue 206.

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
| `wave` | integer | The wave this body was spawned with, or **0** for anything not in a wave. Heroes, guards, monsters, and **every body a siege-surge puts on the ground** carry zero — a surge emits a stream, not countable groups, which is why no wipe can be detected during one. The reap pass decrements this wave's living count and nothing else scans. |
| `assigned_team` | integer | **Monsters only.** Which team this monster is a test for, and therefore which team is paid its boon regardless of who lands the killing blow. **0** on everything else. |

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
| `acquire_range` | double | In paces, and wider than `range`, so a body commits to a fight slightly before it can hit. Copied from the archetype row like every other body value, because it varies by archetype — a challenge monster's is deliberately **small relative to its size** so that it wades through a frontline instead of parking in it. |
| `speed` | double | Paces per tick. |
| `cooldown`, `cooldown_max` | integer | Ticks until the next swing is allowed. |

### Mind

| Field | Type | Meaning |
| --- | --- | --- |
| `state` | integer | 1 walking, 2 closing, 3 fighting, 4 leashing home, 5 dying, 6 waiting, **7 recovering**. |
| `incoming_dps` | double | Damage per second currently aimed at this body — the summed output of everything that has taken it as a target. Maintained rather than recomputed. Read by the healer's choice of who to mend and by the decision to fall back. |
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
| **wave unit** | **yes**, from the lane it was spawned for | — | yes |
| **hero unit** | **never, at any strength** | — | yes |
| **guard** | — | **yes**, from the tower it belongs to | yes |
| **challenge monster** | never | — | **no** — it is on nobody's team |

### Everything is stamped. Nothing is ever read through a reference.

**Every body's vector is a copy it owns.** *Settled; see
[open questions](020-open-questions.md), F23.* Nothing in the swing path
dereferences a lane, a tower, or a team record to find out how strong a body is.
The vector is right there, in the body's own slot, and applying it is a flat walk
over a small array.

That is the whole performance argument, and it is also a correctness argument:
there is no such thing as a stale reference to a slot that moved, because nothing
holds a reference to a slot.

**The price is that the copies have to be corrected when the source changes**,
and that is done by an explicit sweep rather than by anybody re-reading anything:

> **Clear, then re-stamp.** When the thing a body's vector was copied from
> changes, every affected body has its vector cleared and rebuilt from scratch.
> Not patched — cleared. A rebuild from the current truth cannot drift; an
> incremental adjustment can, and will, in the direction nobody tests.

There are exactly three moments that trigger a sweep:

| When | Which bodies are swept |
| --- | --- |
| An upgrade **arrives at or leaves a lane's towers** — which happens at a wave spawn, not the instant it is queued | every guard in that lane |
| A **boon is chosen** | every living body that team owns, which during a calm means the heroes waiting at the library and nothing else |
| A body **spawns** | that body, from its lane or its tower, plus its team's boons |

**Wave units are never swept.** They are stamped at birth and keep what they were
born with until they die — which is not an oversight, it is the design consequence
that makes the whole chest worth arguing about: **moving an upgrade out of a lane
does not weaken the soldiers already walking in it.** They finish their lives
carrying it. Players should be told this outright, because it turns every
reassignment into a decision with a delay, and a delay is what makes a
reassignment worth arguing about.

**Guards are swept, and wave units are not**, and the difference is worth a
comment at both call sites so that nobody later "fixes" the inconsistency. A wave
unit walks away from its lane and dies somewhere else; a guard stands at the
thing it copied from for its whole life, so a guard whose tower has changed and
whose vector has not is a visible lie. Note also that a lane's tower slot
delivers **melee** upgrades to the guards and **ranged** upgrades to the tower
itself, with common ones going to both — see F21.

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

**Dying.** One tick of bookkeeping: pay every player on the opposing team,
decrement this body's wave's living count, free the slot.

**Waiting.** A hero bought during the calm, standing at its own library until
spawning resumes. It does not advance, does not acquire, and cannot be hurt by
anything, because by then the map is empty in both directions. On the tick the
calm ends it goes to walking and marches out with the first wave of the new
phase. *Settled; see [open questions](020-open-questions.md), A17 and F24.*

This is one of the two states where a body is doing
nothing useful — which makes it the only place in the game where a body can have
a personality. A waiting hero should **meander, idle, and turn to look at the
other bodies standing around it.** Nothing about that is mechanical and none of
it may touch the world; it is the one moment a player watches a body they paid
for and nothing is at stake. Spend it.

Note the deliberate asymmetry with walking home at the *start* of a calm, which
is **not** a state — it reuses leashing, with the leash set to the team's own
library. Leaving the map is a thing the brain already knows how to do. Standing
still with intent is not.

**Recovering.** A wounded body that has pulled out of the line to mend, either
waiting beside a healer or regenerating at its own tower. It returns to walking
when the frontline turns against its team — **the line pulls its wounded out while
it is winning and feeds them back in while it is losing**, with nobody deciding
that centrally. The full rule, including where it goes when it comes back, is in
[standing off and falling back](022-standing-off-and-falling-back.md).

This is the seventh state, and it is the one most likely to be got wrong by being
made too eager. A body that withdraws at the first scratch is a body that spends
the match walking; the condition is about **the health on the ground around it**,
not about its own.

### The Golem does not use this

The Eternal Golem never enters closing and never enters fighting. **It walks, and
it attacks whatever it walks into, and it does not stop for either.** There is no
target acquisition, because it is not going anywhere except the library — it
walks the centre lane in a straight line and the frontline is something that
happens to it on the way.

That makes it the one body in the game whose brain is not the five-state machine,
and the exception has to be written where somebody will find it rather than
discovered by whoever wonders why the Golem parks. See
[boons and the challenge](015-boons-and-the-challenge.md).

### Choosing a target

Ranked, cheapest test first, ties broken by the `tie` random stream so that two
identical soldiers do not both pick the leftmost enemy every single time:

1. An enemy soldier already attacking me.
2. **The lowest-health enemy soldier** within acquisition range.
3. An enemy structure within weapon range.
4. Nothing — keep walking.

**Lowest health, not nearest**, and the change is worth its own sentence:
**bodies should finish things.** A rank that spreads its damage across everything
in front of it kills nothing and dies anyway; a rank that concentrates removes an
enemy from the fight and lowers the incoming damage for everybody behind it.
Focus is how a smaller force beats a larger one, and this design has no way for a
player to arrange it by hand — so the brain has to do it.

Structures rank below soldiers deliberately. A soldier that walks past a
defended tower to chew on the tower is a soldier that dies for free, and a
frontline made of those never moves.

**There is more to the brain than this**, and it lives in
[standing off and falling back](022-standing-off-and-falling-back.md): how a
ranged body keeps its distance, how a wounded one leaves the line and comes back,
and how a healer chooses. Those are rules on this same record and this same
dispatch table — not a second controller — but they are enough of them to want
their own page.

## Forming a frontline

Soldiers do not overlap and do not push each other. When a soldier in the
closing state would end its move inside the personal space of a friendly soldier
ahead of it, it stops short instead. The result is a queue: the front rank
fights, the ranks behind stack up along the lane and step forward as the front
rank dies. This is what makes a wave read as a *wave* rather than a smear, and
it is what makes a lane upgrade legible — a stronger front rank visibly holds
its ground while the enemy queue backs up.

### Ranged bodies do not queue

**A rank is a melee thing.** *See [open questions](020-open-questions.md), F22.*
The rule above was written when every body wanted the same place — the front —
and everything behind was waiting its turn to get there. A ranged body does not
want the front and never did.

So the queue has two behaviours rather than one:

- **Melee bodies form the rank.** Front rank fights, the ones behind stop short
  and step forward as it thins. Unchanged.
- **Ranged bodies hold at their own reach behind the rank** and shoot over it.
  They are not queuing for a place they will eventually take, so treating them as
  ranks-in-waiting pushes them into melee range and deletes the distinction
  entirely.

A captain does whichever its own reach says, which is the whole of what makes a
melee captain and a ranged captain different bodies.

The consequence for how a frontline reads: **a lane's depth is now informative.**
A wave that has lost its melee rank but kept its ranged bodies is a wave that is
about to evaporate, and it looks different from one that has lost everything —
which is a thing a player can see and act on from across the map, without a
number anywhere.

Related: [the map](002-the-map-and-its-milestones.md) ·
[combat and damage](006-combat-and-damage.md) ·
[waves](005-waves-and-when-one-is-finished.md) ·
[hero units](012-hero-units.md)
