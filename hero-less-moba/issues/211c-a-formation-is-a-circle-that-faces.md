# 211c — A Formation Is a Circle That Faces Where It Is Going

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 211b |
| Blocks | 211d |
| Reads | [waves and when one is finished](../docs/005-waves-and-when-one-is-finished.md), [the frontline is a queue](206-the-frontline-is-a-queue.md) |
| Open questions | none |

## Current behavior

A formation is a **wide thing at a distance-along**. Its position is one number, the
anchor, which is its **front**. Every body's place is that number plus a fixed
offset backwards, and a fixed offset sideways. It has no orientation of its own: it
is always square to the road, because the road is what its coordinates are measured
in, and when the road turns the whole block turns with it.

That is why a rank survives a corner, and it is also why a wave can only ever be
pointed exactly down its lane.

## Intended behavior

**A formation is an oriented disc.** *Settled; see
[open questions](../docs/020-open-questions.md), H5.*

| | |
| --- | --- |
| its position | the **centre of its bodies** — not the front |
| its radius | **exactly half its width** |
| its local X | the **diameter**: the face of the line, along which the rank stands |
| its local Y | points at **whatever it is walking toward** |

So a formation turns to face where it is going, and its rank is always across that
direction. Where the current design has a block that is square to the road and turns
only when the road does, this has a disc that can be angled relative to the road it
is standing on.

### The centre, not the front

The anchor becomes the centre of the bodies. This is a real change of meaning and
several things read it:

- **Which zone the formation is in** — and therefore when the waypoint advances — is
  a question about the middle of the wave.
- **Whether the wave has run into something** is still a question about the *front*,
  which is now the centre plus the radius along the local Y rather than the anchor
  itself. A wave that stopped when its middle reached an enemy would have walked half
  of itself through them.

### What it faces is a frontline, not a formation

When there is an enemy, the local Y points at **the centre of the enemy's
frontline**: their diameter displaced along their own local Y. Not the centre of
their formation.

The difference is the whole reason to say it. The middle of an enemy block is behind
the people who will actually be hit, so a formation aiming there is aiming past its
own engagement — it arrives at an angle that puts its flank against their front.
Aiming at the frontline puts face against face.

When there is no enemy, the local Y points at the waypoint from
[211b](211b-every-zone-holds-a-waypoint.md).

### A turn moves a body's place out from under it

This is the consequence that makes the change cost something. Today, a rank going
round a bend keeps every body at the same distance-along, so nobody's intended place
moves relative to anybody else's — the road carries the line round as a line, for
free.

A formation that **rotates** does not get that. When the disc turns, a body on the
outside of the turn has its intended place swing away from it while a body on the
inside has its place swing toward it. Both have to move to catch it: one accelerates,
one gives way, and both by more than the current cohesion budget allows.

So the speed clamps have to open up, and that is [211d](211d-marching-speed-is-not-running-speed.md).

## Suggested implementation steps

1. Give the wave a facing: a unit vector in lane coordinates, eased toward its
   target rather than snapped, so a formation visibly turns rather than flicking.
2. Move the anchor's meaning from front to centre, and **find every reader**. The
   contact check, the zone test, the sandbox's measurements and the invariants all
   read it, and every one of them means something slightly different by it.
3. Lay each body's place out in the formation's own frame — rank along the local Y,
   file along the local X — and convert to lane coordinates once per body per tick.
4. Compute the enemy frontline: their centre plus their radius along their facing.
   Find the nearest hostile formation rather than the nearest body, because a body is
   not a frontline and chasing one would turn the whole wave to follow a straggler.
5. In the sandbox: a formation approaching another at an angle must **turn to face
   it** before contact, and the two must meet face to face rather than corner to
   corner. That is the measurement this issue exists for.

## Related documents and tools

- [Waves and when one is finished](../docs/005-waves-and-when-one-is-finished.md)
- [The frontline is a queue](206-the-frontline-is-a-queue.md)
- The formation sandbox, which already measures the box a formation holds through a
  corner and will have to measure its angle as well
