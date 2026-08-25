# 012 — Hero Units

**Datapath document.** Covers the bodies a player buys: what makes them different
from a wave unit, where they are allowed to appear, and what happens when they
die.

## What a hero unit is

A soldier record with `flavour = 2`. That is the whole of it. Same movement, same
targeting, same combat, same brain. The differences are values:

| | Wave unit | Hero unit |
| --- | --- | --- |
| Combat weight | 1 | About 2.5 |
| Abilities | None | One or two, fired automatically |
| Obeys sign-posts | No | Yes |
| Paid for by | The team's spawn timer | A player's personal resource |
| Lane upgrades | Every one in its lane | **None, ever** |
| `owner` | 0 | The buying player's number, 1–6 |
| On death | Nothing | Nothing. It is gone. |

"About 2.5" is a weight, not a stat. A hero might be 2.5× the health at 1× the
damage, or 1.2× both with a very good ability. The catalogue holds the actual
numbers and the balance validator checks that each hero's computed weight lands
in the intended band.

**Heroes do not respawn.** They fight until they die and then they are gone, and
the resource that bought them is gone with them. This is the sharpest difference
from the games this one is subtracted from, and it is what stops a hero from
becoming the thing the player pilots. You cannot form an attachment to a body
that has a life expectancy of ninety seconds. What you form an attachment to is
the *decision* — when to spend, where to put it.

**With one exception: a hero that survives a challenge is refunded.** *Settled;
see [open questions](020-open-questions.md), F14.* When a challenge monster dies,
that team's bodies walk home; the wave units disappear and the heroes hand back
what they cost.

So a hero bought for a challenge is only *spent* if it fails. That is deliberate
and it is narrow — it applies to nothing else, and a hero lost in ordinary play
is lost the ordinary way. What it buys is that throwing everything you have at a
monster is the correct move rather than a gamble against your own next three
minutes. The one fight in the game that is designed to be fought all-in is the
one fight you are allowed to go all-in on.

## Abilities

One or two per hero, each an entry in an ability dispatch table, each firing
automatically when its cooldown is ready and its condition is met. There is no
cast key and no targeting cursor. The vision's line that heroes "behave like
regular units" is taken as binding: a hero is a soldier you pointed, not a puppet
you drive.

An ability is a function of (world, caster, target) that writes into the same
pending-damage buffer as an ordinary swing, resolves on the same tick boundary,
and passes through the same armour arithmetic. There is no second damage system.
See [combat and damage](006-combat-and-damage.md).

**Players get no manual control over a hero. None at all.** Not a hold-position,
not a focus-this, not a manually triggered ability. *Settled; see
[open questions](020-open-questions.md), D2.*

Once a hero is bought and its spawn destination chosen, the only influence a
player has over it is the sign-post standing at a junction it has not reached
yet — and each body obeys at most one sign-post in its life, after which it goes
straight on at every junction. So a hero that has already turned once is beyond
reach entirely. See [sign-posts and lane routing](013-signposts-and-lane-routing.md).

This is the rule that protects everything else. "Heroes behave like regular
units" is the constraint that keeps the soldier brain the *only* brain, and in a
game with the heroes subtracted out, that brain is the whole product. Every piece
of manual control that gets added is a behaviour the brain no longer has to be
good at, and the end of that road is a game where the soldiers are visibly
stupider than the things you drive.

It also protects the chest. A player's hands are busy placing, locking, and
objecting; a hero demanding attention would compete directly with the system that
replaced heroes in the first place.

What this concentrates the design into: **the ability condition table.** With no
player able to intervene, a hero's entire personality is the predicates that
decide when its abilities fire — target below a health fraction, three or more
enemies in a radius, self below a health fraction, a structure in range. Two
heroes with identical stats and different conditions are two genuinely different
purchases. That is where the design effort in issue 504 has to go, because there
is nowhere else for it to go.


## When you can buy one

**In every phase except the calm you buy and the hero appears. During the calm
you buy and the hero waits.** *Settled; see
[open questions](020-open-questions.md), A17.*

There is no phase in which purchasing is closed. During a siege-surge and during
a challenge, heroes arrive normally — they are a real answer to a monster, and
during a surge they are one of only two things a player can still do.

The calm is the exception, and only because the map is emptying: every soldier on
the field is walking home, so a body spawned then would have nowhere to go and
nothing to fight. So a hero bought during the calm **stands at your library until
spawning resumes**, and marches out with the first wave of the new phase.

That turns the calm into the one moment a player can deliberately build an
opening push. You have thirty seconds to a minute, a wallet that has been filling
while nobody could spend it, and a map that is about to be empty in both
directions. What you buy in the calm is what walks out first.

**And there is no cap on how many heroes you may have alive** — the ceiling on
your wallet is the limiter instead. See
[commanders and personal resource](011-commanders-and-personal-resource.md).
## Where a hero can be put on the ground

Three destinations. All of them are places the buying team already controls;
there is no dropping a hero behind enemy lines.

### 1. Onto a wave

The player picks one of their team's living waves and the hero appears with it,
wherever that wave currently is, **immediately**. This is the aggressive option:
the hero arrives already at the frontline, in formation, with the wave's
protection around it. It is also the fragile one, because the frontline is where
the enemy's damage already is.

### 2. Onto a guard tower

The player picks any of their own living guard towers and the hero appears at its
node — **unless an enemy stands inside that tower's command radius**, in which
case the spawn is refused and the player is directed to a tower further back.

It is the same circle that decides whether the tower may replace its guards, and
it is drawn for both teams. One radius, both jobs. See
[guard towers](007-guard-towers-and-their-guards.md).

This rule is the whole texture of hero spawning. It means you cannot reinforce
the tower that is actually under attack; you reinforce the one behind it and walk
the hero up. A tower under pressure is a tower whose reinforcements arrive late,
by design, which is what makes the outer towers worth defending *before* they are
in trouble rather than after.

**The spawn is refused, not redirected.** The refusal names the nearest tower
behind it whose command radius *is* clear — found by stepping from the refused
tower's milestone index toward the player's own library — and if there is none,
it names the library. But the player has to issue the command again. Nothing
puts a body somewhere the player did not ask for it to go: a silent redirect is a
fallback, and a fallback in a game where a hero costs a minute of income is a
purchase you did not make.

That is also why the radius is drawn for both teams. A refusal a player could
have seen coming is a rule they learn once; a refusal out of nowhere is a bug as
far as they are concerned.

### 3. Onto the library

Always available; the library cannot be blocked by proximity, because if enemies
are next to your library the game is nearly over anyway. The hero enters the lane
where the **enemy has pushed deepest**, measured in milestones rather than
distance, and walks outward. The lane-choosing rule and the reason it is
milestones is written up in
[the base and the library](008-the-base-and-the-library.md).

This is the defensive option and it is slow: the hero has a long walk. That
tradeoff — arrive now and fragile, arrive late and intact — is the entire spend
decision.

## Routing after spawn

A hero walks its lane like everything else. At a **junction**, it reads the
sign-post standing there and takes the branch the sign-post points at, which may
send it down a connector into the center lane. Wave units ignore sign-posts
entirely. See [sign-posts and lane routing](013-signposts-and-lane-routing.md).

This is the only steering a player has over a hero after it is bought, and it is
indirect: you do not order a hero to turn, you set a sign that every hero passing
that corner will obey.

## The roster

Each commander brings at least three heroes and ideally five. A roster should
cover distinct jobs rather than three grades of the same soldier — something that
holds a frontline, something that kills a frontline, something that kills stone.
A commander whose roster is "small, medium, large" gives its player one decision
(how much to spend) where a commander with distinct jobs gives them two (how much,
and for what).

Related: [a unit and what it carries](004-a-unit-and-what-it-carries.md) ·
[commanders and personal resource](011-commanders-and-personal-resource.md) ·
[sign-posts and lane routing](013-signposts-and-lane-routing.md) ·
[the base and the library](008-the-base-and-the-library.md)
