# 001 — What This Game Is

## The subtraction

Take a lane-pushing game of the DotA / Aeon-of-Strife family. Remove the heroes.
Remove the jungle. Remove the item shop. Write down what is still standing:

- two bases, facing each other
- three lanes connecting them
- stone towers along each lane that shoot whatever walks past
- an endless supply of soldiers that spawn at each base and walk toward the other

Now run it. Both sides emit identical soldiers, the soldiers meet in the middle,
and they kill each other at the same rate they arrive. The frontline oscillates
by a few paces and never goes anywhere. Nothing a player does changes it, because
in the subtracted game there is nothing a player *does*.

That stalemate is the problem this project exists to solve. Everything below is
an answer to the question: **what do you give the players instead of heroes, such
that the frontline moves?**

## The replacement

Three answers, layered, each one operating on a different timescale.

**The stones (slow).** When a team wipes out an enemy wave, **every player on
that team draws a stone** — and no two of them draw the same one. A stone is
yours: nobody can move what you placed with it, and the only way it changes hands
is if you **offer** it to a teammate. Both teams are dealt the identical hand in
the identical order, so nobody is ever ahead on luck.

A stone goes into a lane, into a lane's towers, or into your library, and what it
does there reaches whatever can use it. Over a match a team accumulates a
collection of modifiers spread across three people, and spends its attention
deciding where they sit and who should be holding which. This is the roguelike
layer: what you get is random, what you do with it is not.

**The commander (fast).** Each player picks a commander. Every enemy soldier your
team kills pays every player on it a private currency — gold, mana, blood,
whatever the commander calls it; mechanically it is one number. Teammates earn
identically, so what separates two of them is entirely what they do with the same
money. It buys **hero units**: individual soldiers roughly two and a half times
as strong as an ordinary one, carrying abilities that ordinary soldiers do not
have. A hero is spawned onto a place you already control, walks a lane like
everything else, and fights until it dies. It does not come back. This is the
moment-to-moment layer: you are always deciding whether to bank or to spend.

**The surge (structural).** Three times per match the game changes shape, twice
over. First comes a **siege-surge**: waves stop and a continuous stream pours from
both bases, one body per lane every fraction of a second. **Nothing is taken from
you** — placements stay exactly where they are and you may keep rearranging them
throughout — but for the duration the game stops reading them. Instead it reads
everything a team owns as one flat list and deals it across the bodies coming off
the spawn points, a different split every half second. The surge does not make
you weaker. It makes you *incoherent*: the combination you spent the match
assembling is all still on the field, just never on the same soldier twice
running. What you are arranging while it runs is not the surge — it is what comes
next.

Then the surge ends and a monster appears in the middle — the **Pillar Orc**, then
the **Field Dragon**, then the **Eternal Golem**. Waves come back but every lane's
worth funnels into the wide centre to fight it, carrying whatever you spent the
surge arranging. Kill it and there is a quiet minute in which every player picks
a **boon** from two — the same two offered to everybody on both sides — which
applies to everything that team ever fields again and can never be moved.

The Golem is the last one and it cannot be killed. Damage only slows it, and it
recovers speed quickly, so holding it back takes continuous pressure and buys no
permanent progress. It advances until a library falls. That is what ends a match:
not a clock, not a score — a body, walking, that nobody can stop.

## Why this is not just heroes with extra steps

A hero in a normal lane-pusher is a *body* — a thing you drive around the map. It
concentrates all of a player's agency into one avatar's position. Here, agency is
concentrated into **placement decisions over stones you own**, which has three
properties a hero does not:

1. **It is negotiated.** Your stones are yours — nobody can move what you placed —
   but you can **offer** one to a teammate, and they can offer you theirs. Every
   draw deals a different stone to each of you, so a team is three people holding
   three different things and deciding together where they go. The conversation
   is *here, you take this* rather than *stop touching mine*. See
   [open questions](020-open-questions.md), F29.
2. **It is legible from across the map.** A hero's strength is where the hero is.
   An upgrade's strength is spread across every soldier in a lane, so a lane that
   is winning looks like a lane that is winning, from any distance.
3. **It survives death.** Bodies die. Placements do not. The chest is the only
   thing in the game that accumulates monotonically, which is what gives a long
   match a direction.

## Design pillars

- **The frontline must move.** Any system that does not, directly or indirectly,
  push a frontline is decoration and should be cut.
- **Every player touches every lane.** The base guards' shared radius, the shared
  chest, and the surge dealing every upgrade evenly across all three lanes all
  exist to punish tunnel vision.
- **Soldiers are the only actors.** Heroes, guards, and challenge monsters are
  all soldiers with different numbers on them. There is one movement system, one
  targeting system, one combat system. If the soldier brain is bad, the whole
  game is bad, and there is no second system to hide behind.
- **The simulation does not know it is being watched.** The world advances as
  pure data on a fixed tick and can run with nothing drawing it. Drawing is a
  separate program that reads snapshots. See
  [the viewing layer](017-the-viewing-layer.md).

## Vocabulary

These are the project's agreed terms. Documents, comments, and issue files use
these words and not synonyms.

| Term | Means |
| --- | --- |
| **lane** | One of the three paths joining the two bases. |
| **wave** | A batch of soldiers spawned into a lane at the same instant, tracked as a group. |
| **wave unit** | An ordinary soldier. No abilities. The bulk of everything on the map. |
| **hero unit** | A stronger soldier with abilities, bought with personal resource. Dies permanently. |
| **guard tower** | A stationary shooter standing on a lane. Two per lane, three more inside each base. |
| **guard** | A soldier a guard tower spawns to patrol the ground near it. |
| **base** | The end of the map belonging to one team: three guard towers and a library. |
| **library** | The building that ends the game when it falls. One per base. |
| **stone** | An upgrade, as a physical object: a rune with a colour, held by one player, placed by them into a slot. **A stone belongs to the player who drew it** and changes hands only by being offered. |
| **upgrade** | The same thing, as a rule rather than an object. Use **stone** when talking about the thing a player holds and taps; use **upgrade** when talking about what it does to a body. |
| **draw** | The event that deals one stone to every player on a team. Both teams are dealt the identical hand in the identical order. |
| **offer** | Handing one of your stones to a teammate. It becomes theirs. The only verb in the game that transfers anything. |
| **chest** | The stones a player is holding but has not placed. Per player, not per team — an earlier design had one shared chest per team and the word is a leftover of it. |
| **slot** | A named place a stone can sit: a lane, a lane's towers, or the library. |
| **the two slots** | Shorthand for the choice at a lane: **the lane** (the wave units spawned into it) or **the lane's towers** (both towers on it, and all the base towers). One or the other, never both. |
| **command radius** | The circle of ground around a guard tower. While an enemy stands inside it the tower replaces no guards and no hero may be spawned there. The only thing in the game both teams can see the shape of. |
| **contribute** | Putting one of your stones into the communal pool, where any teammate may place and re-place it. It stops being yours completely — it shows up as simply one of the stones they have. |
| **dismiss** | Marking a communal stone *not my problem*, which hides it from you and nobody else. When every player has dismissed the same stone it becomes visible to all of them again. |
| **green stone** | A moss ball among a tower's bricks, worth **+1** to the die roll made there. Some upgrades leave one behind when placed. They accumulate, and they belong to the place rather than to a body. |
| **bounty stone** | A stone played on a *teammate*, raising what their kills pay in one colour — +1 for a melee or ranged body, +3 for a captain. The one way to invest in somebody rather than give to them. |
| **ping** | A marker a player drops on the map to point at a place. |
| **siege-surge** | The phase where waves become a continuous stream and the chest cannot be touched. |
| **boon** | An upgrade a player chooses, from three, for slaying a challenge monster. Applies to all three lanes, permanently, and belongs to that player. |
| **challenge** | The phase after each surge: a named monster per team marching from the center. The Pillar Orc, the Field Dragon, then the Eternal Golem. |
| **Eternal Golem** | The third and final challenge. Unkillable; damage slows it instead. It advances until a library falls, which is what ends a match. |
| **milestone** | A named checkpoint along a lane, used to measure how deep a push has gone. |
| **sign-post** | A clickable world object at a junction that decides where heroes turn. |
| **commander** | The character a player picks. Determines their resource name and hero roster. |
| **personal resource** | A private wallet, filled by every kill the team lands, spent only on heroes. |

## Where to read next

- The physical world: [the map and its milestones](002-the-map-and-its-milestones.md)
- The heartbeat: [the simulation tick](003-the-simulation-tick.md)
- The plan: [the roadmap](019-roadmap.md)
- What we still do not know: [open questions](020-open-questions.md)
