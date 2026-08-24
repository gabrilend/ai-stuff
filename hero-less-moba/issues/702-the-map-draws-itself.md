# 702 — The Map Draws Itself

| | |
| --- | --- |
| Phase | 7 — Watching It Happen |
| Blocked by | 701 |
| Blocks | 705 |
| Reads | [the viewing layer](../docs/017-the-viewing-layer.md), [the map and its milestones](../docs/002-the-map-and-its-milestones.md) |
| Open questions | the setting's visual language |

## Current behavior

A window that draws nothing.

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
| A tower's health | Falling stone is the second-biggest event in a lane. |
| A tower's upgrades | Otherwise issue 408's whole trade is invisible. |
| A soldier's spawning lane during a challenge | Issue 607's ruling is unexplainable without it. |
| Push depth, per lane, per team | The number the game actually runs on. |

The bodies are drawn from a snapshot's flat arrays as a single batch. There will
be hundreds to thousands of them and they are all the same handful of shapes;
this is the one place in the viewer where the drawing has to be fast, and it is
fast for the same reason the simulation is — flat arrays of numbers, processed
all at once rather than one at a time.

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
