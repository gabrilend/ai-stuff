# 062-the-rest-of-the-brain

What a body does that is not walking forward and swinging.

## What it is for

Everything here is the **soldier brain**, which is still one brain. None of it is a
second controller or a special case for a flavour — it is rules on the common record.

In a game with the heroes subtracted out, that brain is the whole product. There is
no second system to distract from a bad one.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `begin(world)` / `begin_tick(world)` | | — Allocates and clears the healing claims. |
| `stand_off(world, id)` | | `true` if a ranged body gave ground. |
| `orbit(world, id)` | | `true` if it kept station off the shoulder. |
| `should_fall_back(world, id)` | | Whether to leave the line. |
| `should_return(world, id)` | | Whether to go back in. |
| `recover(world, id)` | | — Withdraws and mends. |
| `soonest_to_die(world, id, radius, skip_regenerating)` | | The ally with least time left. |
| `healer` | *(table)* | Five choosers, one per archetype. |

## Standing off

A ranged body backs away when an enemy is inside its weapon range but nearer than the
maximum, **at half speed** — which makes it a tendency rather than a flinch. It should
spend most of its life at the far edge of its own reach: close enough to shoot, far
enough that closing on it costs something.

It backs away **along its lane**, not away from the individual body threatening it. A
body that fled whoever was nearest would be steered by that one soldier and would
wander out of its own formation to escape it.

And it is **contestable** — another ranged body can push into that space and trade at
a distance neither is comfortable at, which is the whole reason this is a movement
rule rather than a fixed spacing.

## Orbiting, and the fight at the shoulders

A ranged body with nothing to shoot does not stand still and does not walk into the
line. It keeps station off the shoulder of the fight, at its own reach.

**Which way is not random.** A body already on one side goes further that way and
**commits for as long as it stays in the same milestone**, so it reads as a decision
rather than as dithering. And then:

> Both sides' ranged bodies do this, so they drift toward the same flanks and end up
> facing each other.

Nothing anywhere says *ranged units should fight ranged units*. It falls out of two
formations each sending their long-reach bodies wide, and it produces the thing every
lane battle should have — a fight at the shoulders as well as one in the middle, with
the flanks resolving on their own timetable while the melee grinds.

**Only around a fight.** "Nothing to shoot" means standing at a battle it cannot reach
into, not three hundred paces down an empty lane. Without that gate every archer
orbits from the moment it leaves the library, which is not keeping station — it is
refusing to march, and it pulls the formation apart before it meets anybody.

## Falling back, and coming back

**It withdraws when its side can spare it**: under fire, hurt, and its team has more
health nearby than the enemy does. **It returns when its side cannot** — the frontline
has turned and it is needed now, in whatever condition it is in.

Read together those are one rule: **the line pulls its wounded out while it is winning
and feeds them back in while it is losing.** Nothing decides that centrally and no
player issues it, and it produces a frontline that visibly thickens and thins.

The condition is about **the ground around a body, not the body itself.** One that
withdrew at the first scratch is a body that spends the match walking.

A guard never falls back. It is standing on ground it was told not to leave, it has no
lane to withdraw down, and the place a wounded body goes to mend is the tower it is
already at.

A body that has fallen back and is walking up again is **outside the cohesion
budget** — it is rejoining rather than out of position, and averaging it in would tell
every body standing exactly right that it was badly ahead.

## Five ways to heal, and they are five different units

The archetypes differ in **shape**, not in strength.

| | Heals | Chooses |
| --- | --- | --- |
| **priest** | one target, slowly and powerfully | the soonest to die |
| **druid** | a regeneration that ticks up, so many run at once | the soonest to die, among those not already regenerating |
| **sunlight paladin** | an area | nothing — an area needs no selection |
| **curse-doctor** | allies in melee range of a cursed enemy | which **enemy** to curse |
| **rain shaman** | a chain, bouncing | the farthest wounded ally that can fully accept the bounce |

Read down and the matching problem appears and disappears: the priest has it fully,
the paladin not at all, the druid spread over time rather than over bodies, the
curse-doctor inverted, the shaman resolved sequentially.

**So the answer to "how do we solve the assignment" is that we do not solve it once.**
Five units answer it five ways, and that difference is what makes them different units
rather than five numbers.

Two of them share an instinct worth noticing: the paladin's choice and the shaman's
bounce both aim at **the body whose gap the heal fits**, rather than at the worst off.
That is a completely different instinct from the priest's — *spend it where none is
wasted* against *spend it where it is needed most* — and a team fielding both has two
healers who will reliably disagree about who matters.

## Soonest to die is not lowest health

Built from current health **and** the damage per second currently aimed at it. A body
at four hundred with nothing on it is fine; a body at four hundred with three enemies
on it is next. Percentage is the wrong measure and absolute health alone is only half
of one — what a healer is answering is *how long has this one got.*

**A healer only takes a target nobody else is already healing.** That sounds like a
courtesy and is not: it stops two healers both reaching for the most wounded body in
sight while everything else bleeds out beside it. When there are not enough wounded to
go round the rule relaxes rather than deadlocking — heal whoever has fewest healers on
them. Somebody gets doubled up, which is a waste, but nobody stands idle, and a healer
with nothing to do is worse than one doing something redundant.

The claims are rebuilt every tick. A claim that outlived its healer would leave a body
permanently un-healable by anybody else, and nothing would ever notice.
