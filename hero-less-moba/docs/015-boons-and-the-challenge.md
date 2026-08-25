# 015 — Boons and the Challenge

**Datapath document.** Covers the three named things that come out of the middle,
what you are given for killing two of them, and the quiet minute afterwards.

## Where this sits in the shape of a match

The phase grid — what spawns, where it goes, what it carries, what the towers are
doing — is in [the siege-surge](014-the-siege-surge.md), and it is not repeated
here. It used to be, in three places at once, and the three copies had already
drifted apart from each other by the time anybody read them together.

What matters for this document: a challenge begins on the tick a surge ends, it
runs on ordinary waves rather than the surge's stream, and every lane's
production goes into the middle for the duration.

## The challenge phase

On the tick a surge ends, a monster appears at the midpoint of the centre lane
for each team, walking toward that team's base. They do not fight each other and
never meet.

Nothing happens to the chest. Whatever a team arranged during the surge is what
its first wave into the centre carries — see
[the siege-surge](014-the-siege-surge.md).

**There are three challenges in a match and they are always the same three, in
the same order:**

| | Challenge | | |
| --- | --- | --- | --- |
| 1 | **The Pillar Orc** | killable | pays a boon |
| 2 | **The Field Dragon** | killable | pays a boon |
| 3 | **The Eternal Golem** | **cannot be killed** | **pays nothing, and ends the match** |

A fixed, named sequence rather than a random draw. A player who has played one
match knows what is coming in the next and can build toward it — the same
reasoning that put the surge on a visible clock. The escalation is the point: the
first two can be beaten, and then the third one cannot.

### Waves come back, and everything goes to the middle

During a challenge the spawner returns to **waves at the normal interval** — not
the surge's stream — and redirects all three lanes' worth into the center lane.

The lull between waves is the point. A stream would pin a monster in place
indefinitely, because there would always be another body arriving. Waves give the
monster room to **lurch**: it walks while the lane is empty and slows when the
next wave lands on it. A challenge you can watch advancing in stages is readable
in a way a continuous grind is not, and a team that loses one wave badly can
*see* the ground that cost them.

The side lanes empty out for the duration. Their towers hold nothing, and the
entire match compresses into one corridor.
**A funnelled soldier carries the upgrades of the lane it was spawned for**, not
the center's. *Settled; see [open questions](020-open-questions.md), A10.* So
placing into the top lane during a challenge still means something — you are
strengthening one of three groups converging on the middle, and a team that had
invested heavily in one lane does not watch that investment evaporate for the
duration. The cost is legibility: three soldiers walking side by side can have
wildly different strength, and there is no obvious way to draw it.

### The center lane is wider

Topographically, permanently, not only during a challenge. All three lanes'
production arriving in one corridor has to be a battle rather than a single file
waiting its turn to die, and a monster has to be able to fight a whole team at
once.

The permanent consequence is larger: **the center lane is where numbers matter
most**, all match long. That is the only real difference between the three lanes,
and it is one number in the map builder. See
[the map](002-the-map-and-its-milestones.md).

### What a monster is

A soldier record with `flavour = 4` and very large numbers. Same movement, same
targeting, same combat. Three behavioural differences, all fields:

- **Ignores sign-posts.** Nothing reroutes it out of the centre lane.
- **Small acquisition range relative to its size**, so it wades through a
  frontline toward the base rather than parking in it.
- **Targets structures at soldier priority** rather than below it, so it does not
  walk past a tower to be shot in the back.

### A monster is on nobody's side

**Monsters are a third team.** *Settled; see
[open questions](020-open-questions.md), F13.* Not team 1's, not team 2's,
allied with nobody and hostile to everything. That matters because during a
challenge both teams' waves are walking down the same corridor as both monsters,
and without a third team a monster aimed at team 1's base would be functionally
an ally of team 2 for the whole phase — fighting alongside them, in their
direction, at no cost to them. That is not a thing anybody designed and it is
what falls out of a two-team world by default.

Each monster is nevertheless **assigned** to one player-team: the one whose base
it is walking at, and whose test it is. The assignment is bookkeeping rather than
allegiance, and it decides one thing — **the assigned team receives the boon when
that monster dies, no matter who landed the killing blow.** A team cannot reach
into the middle, finish off the enemy's monster, and take their reward, and
nobody has to position a hero to steal or protect a last hit.

Which connects to something worth stating once, in the document where the
temptation is strongest: **there is no last-hit accounting anywhere in this
game.** Resource is paid to a team rather than to a player, there is no
experience, and no rule reads who struck last. A body dies and the opposing team
is paid.

### The deadline is the walk

**There is no separate timer. The deadline is how long the monster takes to reach
your library. If it arrives, it destroys the library, and the team whose library
it destroyed loses** — by the ordinary win condition, not a special rule.

A timer is a number on a panel; a monster walking down the center lane is a thing
you can see. A player who has never read a rules screen knows exactly how long is
left, because the time left is *distance*.

Killing one pays an enormous amount to every player on the **assigned** team —
the largest single payout in the game, and it cannot be stolen.

## Dying, waiting, and the calm

Three stages, and the middle one is the surprising one.

**1. Your monster dies, and your side goes home.** Your wave units and your
heroes turn around and walk back. The wave units simply disappear when they
arrive. **The heroes refund what they cost.** *Settled; see
[open questions](020-open-questions.md), F14.*

That refund changes what a hero is, in this one context. Heroes still die
permanently in ordinary play and the resource dies with them — nothing about that
has moved. But a hero bought *for a challenge* is only spent if it fails, which
is what makes throwing everything you have at a monster the correct move rather
than a gamble against your own next three minutes. The commander economy is
allowed to go all-in on the thing that is designed to be fought all-in.

**2. You wait.** Until the other team has finished theirs, there is nothing to do
but watch them fight. No push, no free ground, no tempo — your bodies have
already left the field. **This answers A8c**, and it answers it in the least
generous direction available: finishing first buys time to think, and nothing
else.

**3. The calm.** Once both monsters are down and both sides are walking home, the
quiet window opens.

**The challenge ends when both monsters are dead, and then everyone goes home.**

Spawning stops, and **every soldier still on the field turns around and walks
back to its own base**, where it leaves the game. Nobody fights on the way. The
map empties out.

The calm lasts **somewhere between thirty seconds and a minute** — a balance
value, and one that has to be found by watching people use it rather than by
reasoning. In that window:

- **Each player chooses a boon, from two offered.** *Settled; see
  [open questions](020-open-questions.md), F5 and F6.* One pick per player, made
  independently, so a three-player team gains three boons at once and each of
  them applies to everything the team fields.
- **The same two are offered to everybody.** One pair is drawn per event and all
  six players see it — not per player, not per team, per *match*. Nobody is ever
  handed a better menu than anybody else.
- **The board can be rearranged**, as it can in every other phase. Nothing was
  dumped and nothing needs rebuilding; this is simply an unhurried minute in
  which to do it.

**This is the only moment a boon ever arrives**, and it happens **twice a match**
— after the Pillar Orc and after the Field Dragon, never after the Eternal Golem,
which is never slain.

The rejected alternative was the vision's own timing: a boon at the end of each
surge, before the challenge, as equipment for fighting it. Three events instead
of two. It is rejected because a boon issued then is a menu opening while
something enormous starts walking — three players reading two lists each, with a
deadline, at the most frightening point in the match — and because equipment
chosen against a monster you have not met yet is a guess rather than a read.
Payment for the kill, in the quiet afterwards, is a reward with room to enjoy it,
and that is the whole reason the calm exists as a phase.

### One pair, six players, and the argument you cannot have

Everybody is offered the same two. That is the shared-deck principle arriving
somewhere new — **remove every source of asymmetry that is not a decision** — and
it has three consequences worth designing toward rather than discovering.

**A team can take three of the same boon.** Duplicates stack, so three players who
all pick the left-hand option are running it at triple strength. Nothing forbids
it, and choosing between concentrating and spreading is the actual decision.

**It is the one negotiation with no channel underneath it.** Three teammates look
at the same two cards, each guessing what the others will take. There is nothing
on the board to lock, object to, mark, or point at — the five verbs a team has for
talking about the chest are all useless here, because the thing being decided is
not on the map yet. It is the only moment in the match where a team has to
coordinate blind, and it lasts under a minute.

**The enemy's boons are legible without an interface.** They chose from the same
pair you did, so after a calm you know their three are some split of two kinds you
are holding yourself. What you do not know is the split. Which is the same shape
as every other information rule in this design: you know *what*, never *how much
of which*.

Then spawning resumes and normal play starts again.

### Why everyone walks home

Two reasons, and the second one is the bigger.

**It makes the calm actually calm.** A quiet minute with a frontline still
grinding away in it is not a quiet minute; it is a minute where you are supposed
to be choosing and are actually watching a lane collapse. Draining the map is
what turns the window into a reward rather than a distraction.

**It resets the frontlines to nothing.** After each of the first two challenges,
both teams start pushing again from their own bases, with whatever stone is still
standing. A match therefore has **three fresh starts** rather than one long
accumulation — the territory resets, the stone does not, and the chest does not.
What carries forward is what you built, not where you happened to be standing.

That has a consequence for the push-depth numbers: they are a measure of where
your **living** soldiers are, not a high-water mark, so a calm drops every lane's
push depth back to the base. The system that maintains them incrementally needs a
full recompute at the end of a calm — the one moment in a match where the
frontline moves backwards for everybody at once. See
[the map](002-the-map-and-its-milestones.md).

**During the challenge itself, push depth is ignored entirely.** *Settled; see
[open questions](020-open-questions.md), F17.* Every lane's production is in the
middle and the side lanes are empty, so the only bodies left standing in them are
each team's own tower guards, sitting at their own towers. The number would read
each team's stone back at them and mean nothing. Nothing consults it while a
challenge runs, and the rule that picks a lane for a hero spawned on the library
does not apply either, because there is only one lane anything is walking down.

### Why a boon is paid for the kill

**A boon is payment for slaying a challenge monster**, not for surviving a surge.
That distinction is the whole reason the calm exists. A boon handed out at the
moment a monster *appears* would be a menu opening while something enormous
starts walking — three players reading three lists each, with a deadline, at the
most frightening point in the match. A boon paid for the kill, in the quiet
afterwards, is a reward you get to enjoy.

Three people each picking from three options is a lot of choosing. Giving it its
own phase, with an empty map, is what makes that a good minute rather than a
chaotic one. **If the calm is ever shortened for pacing, the boon choice stops
being a choice and becomes a thing you click through.**

### What a boon is

| | Ordinary upgrade | Boon |
| --- | --- | --- |
| Where it applies | one slot the players choose | **all three lanes at once**, automatically |
| Can be moved | yes | no. It has no slot. |
| Survives a surge | no — a surge dumps everything into the chest | **yes.** Kept for the rest of the match. |
| Scattered by a surge | yes — dealt three ways | **no.** A boon is on every body, always. |
| Who owns it | the team | **the player who chose it** |

That last row is new and it matters. Everything else in the chest belongs to the
whole team and can be moved by any of them. **A boon is the one thing in the game
that is yours** — chosen by you, permanent, unmovable, and applying to everything
your team puts on the field. In a design built almost entirely out of shared
property and negotiation, a boon is a player's only moment of sole ownership.

**And a boon reaches heroes.** *Settled; see
[open questions](020-open-questions.md), F4.* A lane's upgrades never do — that
is A14, and it exists so that stacking one lane and buying heroes into it cannot
compound. A boon is not in a lane. It has no slot, it cannot be aimed, and it is
best understood as **a buff on the commander that radiates out to everything that
team puts on the field.** There is no placement decision for it to multiply with,
which is exactly why it is allowed where a lane upgrade is not.

**How many accumulate**, in one table, because the numbers are easy to state
wrongly and this document has done so before:

| | Per event | Over a match |
| --- | --- | --- |
| Boon events | — | **two** — after the Orc, after the Dragon |
| Offered to each player | two | 2 + 2 |
| Chosen by each player | one | **two boons per player** |
| Gained by a three-player team | three | **3, then 6 — six per team** |

So both sides finish a match running six permanent, team-wide upgrades nobody can
move and nothing can take away, and soldiers late in a match are simply bigger
than soldiers early in one. **That accumulating floor is the match's arc.**

And each player gets exactly **two moments of sole ownership** in a design
otherwise built entirely out of shared property and negotiation — both of them
paid for by killing something enormous.

---

## The Eternal Golem

**The third challenge, always. Two of them, one per team, and neither can be
killed.**

This is what ends a match. Three surges is a finite structure, and without
something after the third one a match has no escalation left and could grind
indefinitely. The Golem is that something, and it is not a timer or a scoring
rule — it is a body, walking, that nobody can stop.

### Damage is a brake, not a wound

The Golem has no health to remove. Damage dealt to it **slows it down** instead.

- The more damage it takes, the slower it moves.
- **It recovers speed rapidly.** A team that stops hitting it watches it
  accelerate within seconds.
- Keeping it slow therefore requires **continuous** damage, not a burst.

Every other fight in this game is an accumulation: you chip a thing down and the
progress you made is progress you keep. **The Golem is the one fight where
progress is not kept.** You are not reducing something, you are holding something
back, and the moment you stop holding, it is exactly as fast as it was before you
started.

That single inversion is the whole endgame and it needs no new systems — the same
damage arithmetic, the same soldiers, the same upgrades, pointed at a number that
heals.

### It fights on the move

Unlike the Orc and the Dragon, the Golem never stops. It attacks while walking.
There is no configuration of bodies that parks it, no way to make it safe, and
the only variable is **how fast**.

### The waves are its rhythm

With spawning back to waves and all three lanes funnelling into the wide center,
a Golem fights a whole team at once — and then, in the gap before the next wave,
it speeds up and takes ground. A match's final minutes are that pulse: slow,
lurch, slow, lurch, each lurch a little closer to somebody's library.

### It pays nothing, and there is no calm afterwards

**No boon, and no payout for the kill, because there is no kill.** The Golem
cannot die, so there is nothing to be paid for killing it and nothing to
position a hero for. It is the one thing on the map that gives back nothing at
all.

**Everything else still pays.** *Settled; see
[open questions](020-open-questions.md), F9.* Waves keep spawning into the
centre at the normal interval, bodies keep dying, and every death still pays
every player on the opposing team. An earlier draft of this document called the
third challenge "the one stretch of a match with no economy in it at all," which
took a true statement about the Golem and made it a false one about the phase.

What is genuinely gone is the *other* economy and the future. There is no calm
coming, so no boon and no raise to the wallet's ceiling; and every upgrade the
team owns is already applying to the wave units in the centre, so there is
nothing left to arrange. The chest has stopped being a decision.

So the endgame is the stretch where **personal resource is the only live
variable.** Heroes are the only thing a team can still add to the corridor, they
are bought out of a wallet that will never be raised again, and how long a team
holds its Golem back is very largely how well it spends.

### It advances until a library falls

The Golem does not despawn, cannot be killed, and has no end condition of its
own. Each team's Golem advances until it reaches that team's library, and the
first one to arrive anywhere ends the match. The two teams never touch each
other's; each is holding back its own, and **the winner is whoever held longest.**

### What it is

Quoted as it was first written, because it is the most important sentence anybody
has written about this game:

> It doesn't die! It's eternal! It's deathless! It's the same golem in every
> game, watching you play and learning how you fight! Too bad it can't do much
> about it because it's made out of [redacted].

**It is the same Golem in every match.** Not a fresh instance of a monster type —
*the* Golem, the one from last time, and the time before. It watches. It learns.
And it can do nothing with what it knows, because of what it is made of.

In a world where [nobody remembers why](021-nobody-remembers-why.md), the Golem
is the only thing that remembers everything, and it is built out of something that
prevents it acting on the memory.

Mechanically it learns nothing and no part of the simulation consults a previous
match. Those two facts are allowed to sit next to each other. Making it actually
adapt would require the game to remember matches, which is a large feature in
service of a line that works better unimplemented.

What it is made of is not written down, and should stay not written down.

Related: [the siege-surge](014-the-siege-surge.md) ·
[the map](002-the-map-and-its-milestones.md) ·
[the base and the library](008-the-base-and-the-library.md) ·
[nobody remembers why](021-nobody-remembers-why.md) ·
[a unit and what it carries](004-a-unit-and-what-it-carries.md)
