# Visibility is one equation

*Supersedes [sight and what it remembers](007-sight-and-what-it-remembers.md) as
the description of what runs during play. That document still describes the ray
caster correctly, and the ray caster still exists -- see "what happened to the ray
caster" below.*

    visible(viewer, thing)  <=>  reveal(viewer, thing)  >=  threshold(class of thing)

One expression, as many terms as it likes, evaluated in constant time. Not a
loop, not a traversal, not a search.

## Why the constraint, and it is not elegance

A closed form can be evaluated **for any viewer-and-thing pair, in any order, on
any thread, reading nothing another thread writes.** That is exactly the shape
the thread pool asks for: a range and a function, no locks, and the standing rule
that a pass needing a mutex is a bug in the pass.

The old fog could not satisfy that cleanly. Folding sight into a bit-packed array
puts eight cells in a byte and two threads racing inside it. A comparison has
nothing to race on.

And a loop over occluders is not a closed form and never becomes one, which is
why raycasting terrain to the horizon was four orders of magnitude over budget
rather than four times.

## The terms

**Reveal is authored.** A level per structure per viewer, set by the DM. The DM
organises their geometry and flips a switch when they want it seen.

**Threshold is per class.** So one authored number serves every kind of object at
once: set a room to three and its walls and furniture appear, while the goblins
at a higher threshold stay in the dark. Raise it and they walk out. **The DM
never touches an individual creature**, which is what makes this survivable
during a combat.

**The gradient is a distance field.** Flooded outward from the viewer through
open space, cached, and read as one lookup. This is a *Dijkstra map* in roguelike
usage; a *distance transform* or *distance field* generally; a *flow field* when
you walk down it to find a route.

Flood distance is **not** line of sight. A ray stops at a wall; a flood goes
around it and arrives with a larger number. So tiles just round a bend carry
slightly higher values, and as somebody walks forward those values fall and the
tiles fade in. **A person can therefore see slightly around a corner**, and that
is what a gradual reveal is rather than a defect in it.

## The cache, and what static means

Terms that vary are computed once at the start of a frame. A thing marked
**static** keeps its cached terms until further notice.

Static is **velocity zero and mind zero**. Neither exists yet. Velocity has a
near relative: intent is cleared at the start of each beat, so "no intent this
beat" is already computed. **Mind does not exist**, and the world currently
cannot distinguish a creature from furniture -- it separates them only by sight
range, which conflates a sleeping person with a coffee cup and a security camera
with a rock.

*Static is not a permanent marker*, so something must issue the notice that ends
it. That is the whole difficulty of the scheme and it is invisible until the
session where a room lights up and somebody standing in it cannot see.

## The unseen is a surface

Beyond what a viewer may see, the picture is **not** black.

The boundary plane is filled with a surface composed from **that boundary's own
edge materials** -- so an unrevealed doorway is drawn as *a stone doorway
shrouded in shadow* rather than as a gap.

**It leaks nothing, deliberately.** The fill reads only the boundary, and the
boundary is already visible. The tempting improvement is to sample the far side
so the fill matches what is actually there; that would let a player read the fill
and learn about a room they have not entered.

**And a player can tell it from a wall, also deliberately.** Masonry and an unlit
opening are different materials and look different. You can see that there is a
way through and that you cannot see through it. Otherwise four people walk
repeatedly into what they believe is stone.

## What happened to the ray caster

It stops running during play and becomes an **authoring tool**. A DM deciding
where a structure's boundary goes asks once *what can be seen from here* and gets
an exact answer at human speed. Ninety microseconds is wonderful spent once and
ruinous spent twenty times a second per viewer.

Nothing is deleted. Its tests keep it honest, and an exact answer computed rarely
is what checks an authored answer for sanity.

## And the outbound filter changed job

Fog was the security boundary. Authored visibility is **trusted rather than
enforced** -- on the argument every table already runs on, that the DM's notebook
sits out during a bathroom break and nobody reads it. It is the same answer
[phase 12](../issues/phase-12-progress.md) reached when it decided nothing checks
who you are.

So the filter is not deleted either. It **stops being a secrecy boundary and
becomes a size boundary**: it sends what is revealed because that is what fits
down a wire, not because the rest is forbidden. The leak tests drop from *must
never happen* to *probably a bug* -- with one exception, the aperture fill above,
where a leak would be visible to a player and would be a lie.
