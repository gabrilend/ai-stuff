# 702 — The Map Draws Itself

| | |
| --- | --- |
| Phase | 7 — Watching It Happen |
| Blocked by | 701 |
| Blocks | 705 |
| Reads | [the viewing layer](../docs/017-the-viewing-layer.md), [the map and its milestones](../docs/002-the-map-and-its-milestones.md) |
| Open questions | the setting's visual language |

## Current behavior

The map draws itself — three lanes at their real widths, connectors, milestone
marks, stone with health and slotted badges, both teams' command radii, and push depth
as a band growing along each lane from either end. Bodies are batched by team and have
shadows.

Detail arrives with zoom and never an event: health bars, then upgrade badges, then
which lane paid for a body.

## Intended behavior

The primary read. **A glance should answer "which lane am I losing" with no
number anywhere on the screen.**

That is the design brief and everything else is subordinate to it. The three
lanes, the bodies in them, the stone along them, and the two bases — drawn so
that the position of three frontlines is the loudest thing in the frame.

What has to be distinguishable at a glance:

| | Why |
| --- | --- |
| Team, at any zoom | The whole read is "where does mine stop and theirs start." |
| Wave unit vs hero vs guard vs monster | Four things with four very different meanings. |
| **Melee vs a body with a reach** | The whole of how a line is arranged, and invisible while both are dots. |
| A tower's health | Falling stone is the second-biggest event in a lane. |
| A tower's upgrades | Otherwise issue 408's whole trade is invisible. |
| A soldier's spawning lane during a challenge | Issue 607's ruling is unexplainable without it. |
| Push depth, per lane, per team | The number the game actually runs on. |

The bodies are drawn from a snapshot's flat arrays as a single batch. There will
be hundreds to thousands of them and they are all the same handful of shapes;
this is the one place in the viewer where the drawing has to be fast, and it is
fast for the same reason the simulation is — flat arrays of numbers, processed
all at once rather than one at a time.

### A shot in flight is a tiny dart

Ranged attacks currently happen with nothing between the shooter and the target: damage
lands, health drops, and the arrow does not exist. So the second battle at the shoulders
that the whole orbiting design produces is invisible unless you are watching health bars.

A shot draws a **tiny dart** travelling from shooter to target, and the colour is the
rule worth stating carefully:

| Team shot at | Dart |
| --- | --- |
| the blue team | **red** |
| the orange team | **green** |

**The dart is coloured by who it is flying at, not by who threw it** — which is the
opposite of every other colour on the screen, where a thing is its owner's colour. That
inversion is the point. A cloud of red darts means *blue is being shot at*, read off the
colour alone without tracing any of them back to a shooter, so a player sees who is
taking fire rather than who is giving it. Which side is winning an exchange is the
question, and the answer is the colour of the air.

### Healing has to be visible

**Green, rising, and additive: little `+` marks drifting off a body that is being
healed.** Healing is the one thing in this game that happens to a body without anything
visibly touching it — no swing, no arrow, no contact — so it is currently the only
event on the field with no picture at all. Five healer archetypes were designed to
differ in *shape* rather than in strength, each answering who-heals-whom a different
way, and a player cannot tell any of them apart because none of them shows anything.

Drawn from the healing that actually happened this tick rather than from a healer's
state, so what is on the screen is the effect and not the intent: a healer whose heal
was wasted on somebody already full should show nothing, because nothing happened.

The marks drift up and fade, which is the only motion in the game that is not a body
walking, and that is what makes them read as an effect rather than as a thing standing
on the ground.

### A body with a reach is a wedge

Everything is a disc, and that is one shape too few. **The single most-watched thing
on this field is where the archers are standing** — whether they are in their files
behind the line or fanned out to the ends looking for an angle past their own rank
— and while they are dots differing from the melee by six tenths of a pace of radius,
they cannot be picked out at all. A player watching a rank fan out is watching the
most legible consequence of any rule in the game and cannot see it happen.

So: **anything with a reach is drawn as a wedge.** The archers become findable at any
zoom, which is the whole request, and a fanning rank becomes something to watch
rather than something to take a measurement of.

**The wedge does not point, and that is a decision rather than an omission.** Pointing
it wants a world-space angle, and nothing the viewer holds can produce one. The
body's `facing` is a sign along its own lane, not a bearing — and the field is a
square with the two bases on opposite corners, so a lane runs diagonally and bends;
there is no fixed angle that a sign can be turned into. The other candidate is the
direction the body moved between the two snapshots, which is a real bearing while a
body is marching and is **nothing at all** while it is standing still fighting, which
is precisely when a player is looking hardest. A wedge that spins to a default every
time its body stops is worse than a wedge that never turns.

Pointing them properly wants the lane's tangent at the body's position, which means
the snapshot carrying either a bearing or enough lane coordinate to derive one. That
is a change to what crosses the line between the simulation and the viewer, and it
should be made on purpose rather than as a side effect of wanting a nicer triangle.

It stays one batch per shape per team rather than becoming a draw call per body —
the shape is the only thing that changed, and a second batch is a second texture,
not a second loop. The wedge is generated the same way the disc is, in a few lines
of arithmetic with the same soft edge, rather than becoming a file on disk that has
to be kept in step with the code that assumes its size.

The archetype-to-size table stays out of this. Whether a body has a reach is a fact
the **snapshot already carries**, per body, because the simulation already needed it
— so the shape is chosen from what the body is rather than from a parallel table in
the viewer that goes stale the moment somebody adds an archetype.

Milestones should be visible as marks along each lane, because they are the
game's unit of progress and a player who can see them can read a lane the way the
simulation does.

## Suggested implementation steps

1. Draw the path graph itself — lanes, junctions, connectors — from the static
   map, once, into a cached layer that never redraws.
2. Draw milestone marks along each lane.
3. Batch the soldiers by flavour and team into as few draw calls as the library
   allows.
4. Draw stone with health, and with a badge per slotted upgrade.
5. Draw push depth per lane per team as a bar along the lane, not as a number.
6. Test it by watching a recorded match and asking someone who has not read any
   of this which lane is losing.

## Related documents and tools

- [The viewing layer](../docs/017-the-viewing-layer.md)
- [The map and its milestones](../docs/002-the-map-and-its-milestones.md)

## Settled

**Whole map by default, zoom to inspect.** The camera itself belongs to issue
701; what lands here is what must be **drawable at both scales**.

At default zoom, everything in the list above must read with no camera move.

At close zoom, one thing more, and it is a new requirement: **a soldier's
upgrades must be readable off the body.** That is how an opponent learns your
arrangement — you know roughly *what* they hold because the deck is shared, and
you learn *where they put it* by looking at what walks at you. Leaning in has to
answer that question, or the fog stops being made of walking and starts being
made of the interface not telling you.

Two more the body carries, both close-in only:

- **Which lane paid for it**, during a challenge, when all three lanes' soldiers
  fight in the center carrying their own lane's upgrades. Without a marker,
  issue 607's ruling is invisible and unexplainable.
- **Whether it is a hero, and whose.** Heroes carry no lane upgrades at all, so a
  hero in an enormously upgraded lane is *meant* to look unaffected — a player
  who does not know that is watching a bug.

**There is no fog-of-war system to build.** Nothing is hidden deliberately, so
there is nothing here to implement — only something not to accidentally reveal.
Do not draw enemy slot contents, enemy transits, an enemy chest, or enemy
sign-post directions anywhere.

## Still open

**Fog of war is answered and there is no system for it.** You see the enemy's
upgrades on the enemy's soldiers and nothing else; their board reads two or three
waves late because a change has to transit, spawn, and walk. Nothing is hidden
deliberately, so there is nothing here to build — only something not to
accidentally reveal. Do not draw enemy slot contents, enemy transits, or an enemy
chest anywhere.

**What is the setting's visual language?** [Nobody remembers why](../docs/021-nobody-remembers-why.md)
establishes an automated war nobody started and two archives nobody has read.
That is a strong enough image to build a look from and nothing has been drawn yet.
