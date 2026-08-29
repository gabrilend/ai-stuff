# 1303 -- Visibility is one equation

**Phase:** 13, the world becomes solid
**Blocked by:** [1302](1302-structures-and-elevation.md)
**Blocks:** [1304](1304-the-reveal-is-a-distance-field.md),
[1305](1305-the-unseen-is-a-surface.md)
**Documents:** [visibility is one equation](../docs/110-visibility-is-one-equation.md),
[sight and what it remembers](../docs/007-sight-and-what-it-remembers.md),
[what a viewer is allowed to know](../docs/009-what-a-viewer-is-allowed-to-know.md)

## Current behaviour

Sight is cast, not computed. `sight_ray` walks the walls; `sight_point_visible`
casts a fresh ray for every point that might go on a socket; `sight_compute`
builds a whole visibility polygon by firing three rays at every wall corner. It
is O(corners x walls), measured at about 90 microseconds per body against 17
walls, and it is correct because each ray is independent and has no active set to
get wrong.

That cost is fine for seventeen walls and tens of bodies. Against a world of
thousands of vertices at the ranges this phase wants -- terrain to the horizon --
it is roughly four orders of magnitude over budget, and no amount of care makes a
loop over occluders into a closed form.

Fog is a bit grid folded from those rays once per beat per viewer, and it is the
security boundary: the outbound filter asks it what may be written to a socket.

## Intended behaviour

**One expression, evaluated per viewer per thing, in constant time.** Not a loop,
not a traversal, not a search. It may have as many terms as it likes.

    visible(viewer, thing)  <=>  reveal(viewer, thing)  >=  threshold(class of thing)

`reveal` is composed from cached terms -- the structure's authored level for this
viewer, the distance field of [1304](1304-the-reveal-is-a-distance-field.md),
elevation, emitted light. `threshold` is a constant per class of object.

### Why the constraint is worth enforcing

Not elegance. A closed form can be evaluated **for any viewer-and-thing pair, in
any order, on any thread, reading nothing another thread writes.** That is
exactly the shape the thread pool demands: a range and a function, no locks, and
the documented rule that a pass needing a mutex is a bug in the pass rather than
in the pool.

The old fog could never satisfy that cleanly, because folding sight into a
bit-packed array has eight cells sharing a byte and two threads racing inside it.
A comparison has nothing to race on.

### The DM turns one dial and every class sorts itself out

Because the threshold is per class and the reveal is per structure, a single
authored number serves every kind of object at once. Set a room to three and its
walls and its furniture appear; the goblins have a higher threshold and stay in
the dark; raise it and they walk out. **The DM never touches an individual
creature**, which is what makes this survivable during a combat.

### The cache, and what static means

Every term that varies is computed once at the start of the frame. A thing marked
**static** keeps its cached terms until further notice.

**Static is velocity zero and mind zero.** Neither of those exists yet. Velocity
has a near relative -- the intent pass writes down where every body would like to
be, and intent is cleared at the start of a beat, so "no intent this beat" is
already computed and already zeroed. Mind does not exist at all, and the world
currently has no way to say *this is a creature and that is furniture*; it
distinguishes them only by sight range, which conflates a sleeping person with a
coffee cup and a security camera with a rock.

**Static is not a permanent marker**, which means something has to issue the
notice that ends it. That is the whole difficulty of this scheme and it is
invisible until the session where a room lights up and somebody standing in it
cannot see. See the open questions.

### What happens to the ray caster

It stops running during play and becomes an **authoring tool**. The DM, deciding
where a structure's boundary goes, asks once *what can be seen from here* and
gets an exact answer at human speed. Ninety microseconds is wonderful spent once
and ruinous spent twenty times a second per viewer.

None of it is deleted. `043-test-sight.c` keeps it honest, and an exact answer
computed rarely is the thing that checks an authored answer for sanity.

### And the outbound filter changes job

The fog was the security boundary. Authored visibility is trusted rather than
enforced -- the argument being the one every table already runs on, that the DM's
notebook sits on the table during a bathroom break and nobody reads it.

So the filter is not deleted either. **It stops being a secrecy boundary and
becomes a size boundary**: it sends what is revealed because that is what fits
down a wire, not because the rest is forbidden. The leak tests are downgraded
from *must never happen* to *probably a bug*.

## Suggested implementation steps

1. A `mind` field on a thing, and a decision about whether it is a flag or a
   measurement. If it is a measurement, the ruleset is what reads it.
2. The reveal level: a value per structure per viewer, set by a command, landing
   in the command log like every command and undoable by the rollback phase 3
   built.
3. The threshold table, per class of object, owned by the ruleset.
4. The one expression, in one function, called by the renderer and by the
   outbound filter. **Two callers, one primitive** -- the opposite of the
   deliberate two-implementations arrangement sight has, because there is no
   longer a security boundary for a second opinion to protect.
5. The frame cache, and the static marking, and whatever issues the notice.
6. A test that the expression is order-independent: evaluate every pair in a
   random order on one thread and in spans on many, and compare.
