# 015 — Boons and the Challenge

**Datapath document.** Covers the three named things that come out of the middle,
what you are given for killing two of them, and the quiet minute afterwards.

## The four phases of a match

Because the boon's timing only makes sense inside the whole shape:

| | **Normal** | **Siege-surge** | **Challenge** | **The calm** |
| --- | --- | --- | --- | --- |
| Spawn shape | waves, long interval | a stream, one body per lane | waves, normal interval | **nothing spawns; everyone walks home** |
| Destination | own lane | own lane | **the center, all three** | — |
| Upgrades | placed by the players | **the chest dealt across the three** | placed, by spawning lane | **re-placed freely** |
| What players do | place, buy, point | buy, point | place, buy, point | **choose a boon** |

The calm is short and it happens **three times minus one** — after the Pillar Orc
and after the Field Dragon. It never comes after the Eternal Golem, because the
Golem is never slain.

## The challenge phase

On the tick a surge ends, the whole chest is dumped out unplaced and a monster
appears at the midpoint of the center lane for each team, walking toward that
team's base. They do not fight each other and never meet.

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
have wildly different strength, and there is no obvious way to draw it.

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

- **Ignores sign-posts.** Nothing reroutes it out of the center lane.
- **Small acquisition range relative to its size**, so it wades through a
  frontline toward the base rather than parking in it.
- **Targets structures at soldier priority** rather than below it, so it does not
  walk past a tower to be shot in the back.

### The deadline is the walk

**There is no separate timer. The deadline is how long the monster takes to reach
your library. If it arrives, it destroys the library, and the team whose library
it destroyed loses** — by the ordinary win condition, not a special rule.

A timer is a number on a panel; a monster walking down the center lane is a thing
you can see. A player who has never read a rules screen knows exactly how long is
left, because the time left is *distance*.

Killing one pays an enormous amount to every player on the team that landed the
last blow — the largest single payout in the game, and worth positioning a hero
for.

## The calm, and the boons

**The challenge ends when both monsters are dead, and then everyone goes home.**

Spawning stops, and **every soldier still on the field turns around and walks
back to its own base**, where it leaves the game. Nobody fights on the way. The
map empties out.

The calm lasts **somewhere between thirty seconds and a minute** — a balance
value, and one that has to be found by watching people use it rather than by
reasoning. In that window:

- **Each player chooses a boon, from three offered.** One per player, three per
  team, chosen rather than handed over.
- **The chest gets re-placed.** Everything dumped out when the surge ended is
  still sitting there doing nothing, and this is when it goes back onto the
  board.

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
property and negotiation, each player gets exactly two moments of sole ownership
per match.

Two challenges are survivable, so **six boons per team** by the end: three players
× two kills. By then both sides are running six permanent lane-wide upgrades
nobody can move, and soldiers late in a match are simply bigger than soldiers
early in one. That accumulating floor is the match's arc.

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

**No last-blow payout, no personal resource for damaging it, and no boon.** There
is no last blow because there is no death, and there is nothing left to spend
resource on: every upgrade the team owns is already on the wave units in the
center, every soldier the bases can make is already walking into the middle, and
the entire effort of both teams is spent on one thing.

So the third challenge is **the one stretch of a match with no economy in it at
all.** Nothing is earned and nothing new can be bought. Whatever a team banked
before the third surge is the last thing it will ever field, which turns the
run-up to that surge into a spend-it-all-now moment.

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
