# 211 — Waypoints, and the Zones They Sit In

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 202, 206, 207 |
| Blocks | 212 |
| Reads | [the map and its milestones](../docs/002-the-map-and-its-milestones.md), [waves and when one is finished](../docs/005-waves-and-when-one-is-finished.md) |
| Open questions | none |

**This is the umbrella.** The work is in four sub-issues, listed at the bottom, and
they should be read in order — each one is the ground the next stands on.

## Current behavior

A wave has a single number for where it is: its **anchor**, a double holding how far
along its lane the *front* of the formation has got. Every tick the anchor moves
forward by the wave's pace, and every body's place is that number plus its own fixed
offset. There is no destination, no aiming, no route. The wave walks a number up
toward the lane's length, and its shape follows the road because the road is what
the numbers are measured against.

Progress is measured separately, in **milestones**: nine per lane, at fixed
fractions of its length, which are also where the towers stand. Push depth — the
number the whole game runs on — counts milestones.

Both are coarse and neither has any play in it. Every wave in a lane walks the exact
centre line, at the exact same distances, forever.

## Intended behavior

Two ideas, and the second is larger than it first sounds.

### A wave aims at places, not at numbers

Each lane is cut into **zones**, four times finer than its milestone intervals. Each
zone holds a **waypoint**: one point at a random position inside it. A wave marching
a lane approaches its waypoint, and when the **centre** of the formation enters that
zone, the waypoint becomes the next zone's.

The variation is the point. Nobody standing on the ground knows exactly which
direction is optimal, so you go roughly that way. Two waves marching the same road
on the same map should not put their feet in the same places.

### A formation is a circle with a facing

Not a wide thing at a distance-along. **An oriented disc.**

Its position is the **centre of its bodies**, not the front of it. Its **radius is
exactly half its width**. Its diameter is the *face of the line* — that is the
formation's own local X — and its local Y points at whatever it is walking toward.
So a formation turns to face where it is going, and the rank is always across that
direction.

And what it faces, when there is an enemy, is that enemy's **frontline** rather than
their formation: their diameter displaced along their own Y. Aiming at the middle of
an enemy block is aiming past the people who will actually be hit.

Two things fall out of that and are their own work:

- A turn moves a body's intended place away from where it is standing, so a body has
  to be able to **accelerate to catch it** and slow to let the line come back.
- **Marching speed is not running speed**, and running turns out to belong to one
  specific moment, which is issue 212.

## Suggested implementation steps

**In the sub-issues, and in this order**, because each is the ground the next stands
on: the zones have to exist before anything can be put inside one, a waypoint has to
exist before a formation can face it, and a formation has to rotate before anybody
can say how much a body needs to accelerate to keep up with a rotation.

The one step that belongs here rather than in any of them: **stop when the sandbox
says a formation still holds its line.** Every one of these four changes something
the formation work was measured on, and the measurements are the only reason to
believe any of it. A sub-issue that lands with the sandbox unhappy is not finished
regardless of what it was trying to do.

## The sub-issues

| | |
| --- | --- |
| [211a](211a-the-lane-is-cut-into-zones.md) | The lane is cut into zones, and push is measured in them |
| [211b](211b-every-zone-holds-a-waypoint.md) | Every zone holds a waypoint, and a wave walks to it |
| [211c](211c-a-formation-is-a-circle-that-faces.md) | A formation is a circle that faces where it is going |
| [211d](211d-marching-speed-is-not-running-speed.md) | Marching speed is not running speed |

## Related documents and tools

- [The map and its milestones](../docs/002-the-map-and-its-milestones.md)
- [Waves and when one is finished](../docs/005-waves-and-when-one-is-finished.md)
- The formation sandbox, which is where all of this gets measured
- [212 — a beaten body's one roll](212-a-beaten-body-gets-one-roll.md), which is
  what running is for
