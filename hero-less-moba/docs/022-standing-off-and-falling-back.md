# 022 — Standing Off and Falling Back

**Datapath document.** Covers what a body does that is not walking forward and
swinging: how a ranged body keeps its distance, how a wounded one leaves and
comes back, how a healer picks who to mend, and why the last of those is a
harder question than it looks.

Everything here is the **soldier brain**, which is still one brain. Nothing below
is a second controller or a special case for a flavour — it is rules on the
common record, which is the constraint that keeps the brain small enough to be
good. See [a unit and what it carries](004-a-unit-and-what-it-carries.md).

## The standoff

**A ranged body backs away when an enemy is inside its weapon range but nearer
than the maximum.** It retreats at **half speed** while doing so, which is what
makes the behaviour a tendency rather than a flinch.

The intent is simple to state and does most of the work: **a ranged body should
spend most of its life at the far edge of its own reach.** Close enough to shoot,
far enough that closing on it costs something.

**It is contestable.** Another ranged body can push into that space and trade
shots at a distance where neither is comfortable — so a standoff is a position two
sides can argue about rather than a guarantee. That is the whole reason to make
it a movement rule rather than a fixed spacing.

### Once engaged, the two kinds move at different rates

| | Speed while engaged |
| --- | --- |
| **melee** | **1.0×** — full |
| **ranged, and healers** | **0.5×** — half |

That single asymmetry produces most of what a frontline looks like. Melee closes
at full speed and ranged gives ground at half, so **a melee body that commits
will reach a ranged one** — eventually, having been shot the whole way. The
question a player is watching is whether it arrives with anything left.

It is also why a healer standing in the wrong place cannot simply run home. Half
speed means the decision about where to stand was made some time ago.

## Falling back, and coming back

A body that is taking damage does not simply die where it stands.

**It withdraws when its side can spare it.** If a body is under fire and **its
team has more health nearby than the enemy team does**, it pulls out of the line
to recover. The team is ahead on the ground it is standing on, so it can afford
to be one body lighter for a while.

**And it returns when its side cannot.** If the frontline turns — **the enemy has
more health on it than we do** — the recovering body goes back in. It is needed
now, in whatever condition it is in.

Read those two together and they are one rule: **the line pulls its wounded out
while it is winning and feeds them back in while it is losing.** Nothing decides
that centrally, no player issues it, and it produces a frontline that visibly
thickens and thins.

### Where a body recovers

- **Beside a healer, if one is near.** Wait there.
- **At its own tower, otherwise**, where it regenerates naturally.

So a tower is not only a thing that shoots — it is the place a lane's wounded go,
which gives the ground behind a tower a job it did not have and makes losing one
cost more than its arrows.

### And where it goes when it comes back

**To the ally taking the most damage — by rate, not by total.** A body that has
lost most of its health slowly is not in trouble; a body losing it quickly is.
Reinforcement follows the derivative.

## Choosing what to attack

**The lowest-health enemy in range.** Not the nearest, not the most dangerous —
the one closest to dying.

That is a change from the older rule, which took the nearest enemy inside
acquisition range, and it is worth naming what it buys: **bodies finish things**.
A rank that spreads its damage across everything in front of it kills nothing and
loses anyway; a rank that concentrates removes an enemy from the fight and
reduces the incoming damage for everybody behind it. Focus is how a smaller force
beats a larger one, and it should not require a player to arrange it.

## Healers

### Who a healer mends

**The ally who will die soonest**, which is not the same as the ally with the
least health.

The value is built from two things:

- the target's **current health**, as an absolute number rather than a fraction
- the **damage per second currently aimed at it** — the output of everything that
  has taken it as a target

A body at four hundred health with nothing attacking it is fine. A body at four
hundred with three enemies on it is next. **Percentage is the wrong measure and
absolute health alone is only half of one**; what a healer is answering is *how
long has this one got.*

### The rule that keeps two healers from wasting each other

**A healer only heals a target nobody else is already healing.**

That sounds like a courtesy and it is not — it is the thing that stops the
obvious failure, which is two healers both reaching for the most wounded body in
sight while everything else bleeds out beside it.

And it comes with a positional obligation that is the more interesting half:

> **A healer keeps itself in range of enough wounded bodies that the other
> healers who could claim them cannot claim them all** — so that there is always
> at least one left for it.

**That is Hall's condition, expressed as a movement goal rather than a selection
rule**, and it is a genuinely nice way out of a hard problem. Rather than solving
an assignment across the whole field, each healer *positions so that the
assignment is easy* — keeping its own neighbourhood of reachable wounded larger
than the demand on it. In practice that means **in range of at least three valid
wounded targets**, while staying out of reach of enemy melee and enemy ranged.

**When there are not enough wounded to go round**, the rule relaxes rather than
deadlocking: heal whoever has the **fewest healers on them**, breaking ties by
lowest health nearby. Somebody gets doubled up, which is a waste, but nobody
stands idle — and a healer with nothing to do is worse than a healer doing
something redundant.

### Five ways to heal, and they are five different units

The archetypes differ in **shape**, not in strength, and each one answers the
who-heals-whom problem differently. That is the design rather than a side effect.

| | Heals | Chooses |
| --- | --- | --- |
| **Priest** | one target, slowly and powerfully | the soonest to die |
| **Druid** | one target, as a regeneration that ticks up over time — so it can have many running at once, building up as it applies them one at a time | the soonest to die, among those not already regenerating |
| **Paladin** | an **area**, as an aura, plus a periodic minor heal | for the minor heal: the wounded ally **nearest full health whose gap the heal still fills** — a little overheal is fine, so a 350 heal wants a body missing about 400 |
| **Curse-doctor** | allies in **melee range of a cursed enemy** | which enemy to curse, which is a targeting decision about the other side |
| **Rain shaman** | a **chain** — *chain tide* — bouncing between allies | each bounce prefers the **farthest wounded ally that can fully accept the bounce's value** |

Read down that table and the matching problem from F39 appears and disappears
several times. **The priest has it fully** — one target, contested, assignment
required. **The paladin does not have it at all**, since an area effect needs no
selection. The druid has it spread over time rather than over bodies, the
curse-doctor inverts it by aiming at an enemy, and the rain shaman resolves it
sequentially, one bounce at a time.

**So the answer to "how do we solve the assignment" is that we do not solve it
once.** Five units answer it five ways, and the difference between them is what
makes them different units rather than five numbers.

Two of them share a preference worth noticing: the paladin's minor heal and the
shaman's bounce both aim at **the body whose gap the heal fits**, rather than at
the worst-off. That is a completely different instinct from the priest's — *spend
it where none of it is wasted* against *spend it where it is needed most* — and a
team fielding both has two healers who will reliably disagree about who matters.

### Fortitude

A priest also buffs **fortitude**, which **reduces damage taken**. It draws on the
priest's **constitution** die where the heal draws on its **strength** die — so a
priest's two jobs are paid for out of two different attributes, and a priest that
is good at one need not be good at the other.

**It is cast on bodies the enemy is already looking at**, preferring allies with
**the most health and the most eyes on them.**

That preference is the opposite of the healing rule and deliberately so. **A heal
goes to whoever is closest to dying; fortitude goes to whoever is being hit
hardest and can still take it.** Mending answers damage that has happened;
fortitude answers damage that is about to. Putting it on the body already at
death's door would be spending a reduction on a life that is ending anyway.

Related: [a unit and what it carries](004-a-unit-and-what-it-carries.md) ·
[combat and damage](006-combat-and-damage.md) ·
[waves](005-waves-and-when-one-is-finished.md) ·
[commanders and personal resource](011-commanders-and-personal-resource.md)
