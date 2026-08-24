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

**The chest (slow).** When a team wipes out an enemy wave, that team draws a
random upgrade into a shared chest. The upgrade is not owned by the player who
drew it; it belongs to the whole team, and any teammate can pick it up and drop
it into any lane. A lane's upgrades apply to every soldier that team spawns into
that lane. Over a game a team accumulates a bag of modifiers and spends its
attention deciding where they sit. This is the roguelike layer: what you get is
random, what you do with it is not.

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
both bases, one body per lane every fraction of a second. Nobody can place an
upgrade — instead every single body is stamped with a **randomly selected third of
the team's chest**, so the stream is a shuffled deck walking down a lane. The
surge does not make you weaker. It makes you *incoherent*: the combination you
spent the match assembling is still on the field, just never on the same soldier
twice running.

Then the surge ends, the whole chest is dumped out unplaced, each team is handed
a **boon** that applies to all three lanes and can never be moved, and a monster
appears in the middle — the **Pillar Orc**, then the **Field Dragon**, then the
**Eternal Golem**. Waves come back but every lane's worth funnels into the wide
center to fight it. So the scramble to rebuild your board happens with something
enormous walking at your library.

The Golem is the last one and it cannot be killed. Damage only slows it, and it
recovers speed quickly, so holding it back takes continuous pressure and buys no
permanent progress. It advances until a library falls. That is what ends a match:
not a clock, not a score — a body, walking, that nobody can stop.

## Why this is not just heroes with extra steps

A hero in a normal lane-pusher is a *body* — a thing you drive around the map. It
concentrates all of a player's agency into one avatar's position. Here, agency is
concentrated into **placement decisions over a shared pool**, which has three
properties a hero does not:

1. **It is negotiated.** Your teammates can move what you placed. You can lock a
   placement to stop them; they can object to the lock, and two objections force it open.
   Every upgrade is a small ongoing conversation between three people.
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
| **chest** | A team's shared pool of upgrades. Also called the upgrade pool. |
| **upgrade** | A modifier drawn into the chest and placed into a lane or slotted into towers. |
| **slot** | A named place an upgrade can sit: a lane, a lane's towers, or the library. |
| **lock** | A claim one player puts on a placement so teammates cannot move it. |
| **objection** | A request to release a lock. Two objections from two different teammates force it. |
| **ping** | A marker a player drops on the map to point at a place. Nothing to do with locks — see **objection**. |
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
