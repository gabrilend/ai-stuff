# 214 — Going Round What Is In The Way

| | |
| --- | --- |
| Phase | 2 — Things That Walk and Fight |
| Blocked by | 206, 211c, 111 |
| Blocks | 602 |
| Reads | [standing off and falling back](../docs/022-standing-off-and-falling-back.md) |
| Open questions | G1, G2, G3 |

## Current behavior

**A body that cannot move forward stops, and that is the whole of it.**

[The frontline queue](206-the-frontline-is-a-queue.md) asks one question — would I
end this step inside a friendly body ahead of me in roughly my own file — and the
only answer it can give is *stop short*. There is no sideways.

That was written for a rank forming up, where stopping is right: the front rank
fights and the ranks behind wait their turn. It is wrong everywhere else, and it is
visibly wrong during a siege-surge, where a stream of bodies walking down a lane
concertinas into a stationary column behind whichever one stopped first. They are not
queueing for anything. They are just stuck.

The same rule means one stationary body — a guard, a straggler, anything that has
stopped for its own reasons — is an immovable plug in a lane. Everything behind it
stops, and nothing ever goes round.

## Intended behavior

**Occupied ground is a thing to go round, not a thing to wait behind.**

### Two of them, and they are alternatives rather than layers

**Swarm pathfinding.** Every body for itself. It goes round whatever is in front of it,
and a group crossing the ground is a group only in the sense that it started together.
Cheap, robust, and it will never deadlock — and a wave that walks it stops looking like
an army, which is most of what this game is for.

**Formation-respecting avoidance.** The three rules below: a body steps aside, a
formation gives way to another formation as a body, and a formation does not move for a
stray. More expensive, and it can deadlock in ways the swarm cannot.

**Both get built**, and the comparison is the point rather than a step on the way to
picking one. They are two different answers to "what is a group of soldiers", and the
arena can run the same scene under each — which is the first thing
[111](111-the-proving-ground.md) was built to make possible. It is also likely that the
right answer is neither uniformly: a surge is a stream and probably wants the swarm,
while a wave is a formation and wants the other.

### A body moves sideways between files, not only forward

Underneath both: **a hole in the line ahead of you is a place to rush to.** A body that
can see an opening in the front moves *across* — between files — to fill it, rather than
waiting in its own file for the body ahead to die.

Files, not ranks. A rank is the row standing shoulder to shoulder; a file is the column
one behind another. A body waits behind the body in front of it, which is its file, and
what it needs to be able to do is change which file it is in.

That is what makes a line close up rather than develop holes, and it is the same
movement as stepping aside seen from the other end — one is going round something in the
way, the other is going into somewhere nothing is.

### The three rules

The distinctions between them are the whole of the second design.

### A body steps aside

If the place a body is trying to move into is occupied, it tries to move **to the
side** instead. Not instead of advancing — as the way of advancing. A body that
cannot go straight goes diagonally, and a body that cannot go either way is the only
one that stops.

Which side is a decision and has to be held, the way the orbit's side is held: a body
that picks left on one tick and right on the next has not gone round anything, it has
vibrated.

### A formation goes round a formation

A formation moving to engage — meaning **no enemy is within range of any body that
would be joining it** — gives way to *other formations*, as a body. Two bodies of
troops crossing the same ground do not interpenetrate; one goes round.

That is a decision made once, for the whole group, and not by each body separately.
A formation whose members each independently decided to sidestep is a formation that
has dissolved into a crowd, which is the thing the whole formation module exists to
prevent.

### But a formation does not go round a stray

**A formation does not step aside for a single body, and this is the important half.**
One soldier standing in a field does not move an army. What happens instead is that
the formation walks through the ground it was going to walk through, and **its
individual members filter round the obstacle** and close up again behind it — which is
the first rule doing its job inside the second.

So the picture to check the design against: a formation crossing the arena, one
allied body standing still in the middle, and the formation **keeping its line and
its heading** while a hole opens and closes around the one body as it passes through.
The formation is not deflected. The bodies are.

## Suggested implementation steps

1. Build the arena scene first — see [111](111-the-proving-ground.md) — and watch
   what happens today. The design above is a description of what should be seen, and
   it should be checked against a picture before it is checked against code.
2. Give the queue a second answer besides stopping: a sideways step, with the side
   chosen once and held.
3. Decide what counts as a formation being under way rather than fighting, in the
   terms the formation module already has — its anchor, its members, whether any of
   them has a target.
4. Give the formation's plan a sideways offset of its own, against other formations
   only, so that going round is one decision applied to every member's place rather
   than a decision each member makes.
5. Assert the picture: the line's heading and width are unchanged as it passes the
   stray, and no member ends up standing inside it.

## Open questions

**G1. How far to the side, and for how long?** A step aside that is too small never
clears anybody; one that is too large is a body leaving its file over a pebble. And
having gone round, when does a body stop going round?

**G2. What decides which side?** For a single body the cheap answer is whichever side
it is already nearer, the way the orbit picks. For a formation meeting another
formation there is a right answer and a wrong one, and both may pick the same.

**G3. Does a body going round give up its place, or carry it?** A body that keeps its
formation slot while stepping round will be pulled back into line by the cohesion
budget while it is still going round the obstacle, which may be exactly right or may
be the two rules fighting each other.

## Related documents and tools

- [The frontline is a queue](206-the-frontline-is-a-queue.md) — the rule being changed
- [A formation is a circle that faces](211c-a-formation-is-a-circle-that-faces.md)
- [The proving ground](111-the-proving-ground.md) — where this is looked at
