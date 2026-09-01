# Ways This Could Go Wrong

Written before most of it exists, which is the only time this list is honest.
Afterwards it becomes a record of what did go wrong, which is a different and
less useful document.

## A ball gets inside a wall

The likeliest bug in the project and the one that is hardest to see. A ball that
moves further than its own radius in one tick can pass a wall face without ever
being within the radius that triggers the collision, and once it is inside the
stone every rule gives a wrong answer — the floor under it is the top of the
block it is inside, so it is standing on nothing, so it falls forever.

Guarded three ways: a speed cap that keeps one tick's motion under a radius, the
fixed timestep that makes the cap meaningful, and a headless test that runs
thousands of balls and asserts none of them is ever at a position whose column
has stone at its height. The test is worth more than the two guards, because the
guards can be defeated by a number somebody changed.

## The corner case, literally

Two walls meeting at a corner leave a diagonal gap between them if only the flat
faces are tested. A ball crossing that gap looks exactly like a ball going
through solid stone, and it happens rarely enough to be dismissed as a glitch.
Named in [rolling](013-rolling-with-momentum.md) as the single most likely bug in
that file, and the collision must push away from the corner *point*, not from
either face.

## The maze is not connected and nobody notices

A generator that produces a maze in two pieces is a generator whose bodies pile
up in whichever piece they spawned in. From a camera two hundred cells away that
looks like a busy corner and a quiet one, which is what a maze is supposed to
look like.

The validator's component count is the guard, it runs on every generated maze,
and a count above one is a hard error rather than a warning. A warning here would
be ignored the first time and invisible the second.

## Determinism rots quietly

Every rule in [named streams](005-randomness-comes-from-named-streams.md) exists
because determinism does not fail loudly. It fails by one system taking a number
from somewhere it should not, and the symptom is that a bug report from three
weeks ago no longer reproduces.

The test is to run a seed twice and compare a checksum of every body's position
after some thousands of ticks. It is cheap, it runs on every build, and it is the
only thing standing between this project and a category of bug that cannot be
investigated.

The specific mistake to watch for: **the viewer drawing from a simulation
stream.** Then the simulation depends on whether anybody was watching, and two
runs of one seed diverge based on whether somebody pressed a key. The camera has
its own stream to make that mistake impossible rather than merely discouraged.

## The renderer allocates and the frame rate stutters

Anything allocated per frame is collected eventually, and the collection lands on
one frame. A stutter every few seconds, correlated with nothing.

The rule is that the render sweep allocates nothing: the body buckets are
preallocated count-and-offset arrays rather than tables of lists, the face
polygons are written into one reused vertex array, and the culling range is
integers. It is easy to hold and easy to break by adding one convenient table
inside the loop.

## Somebody unifies rolling and walking

The tempting refactor. They look similar, both move bodies, and one function with
a `smooth` flag would be fewer lines.

It is wrong because they ask the stone different questions —
[locomotion](012-locomotion-is-a-dispatch-table.md) says why — and the result is
a function with two halves and a branch at the top, which is a dispatch table
with one row and worse ergonomics. Written down here because the refactor will
look correct to somebody who has not read that page.

## The simulation reaches for the engine

One file asks the graphics library for the elapsed time, and headless stops
working, and it stops working in a way that looks like an unrelated crash three
files away.

The guard is a grep test over `src/`. Crude, and it has caught this exact mistake
in projects shaped like this one.

## The population grows and the meet pass does not

The spatial buckets keep the meet pass proportional to the number of bodies
rather than to its square. That property depends on bodies being spread out. A
hundred bodies in one cell — which is what happens when a spawn point is wrong,
or when a pit collects them — puts them all in one bucket and the pass is
quadratic again, on the tick where things are already going badly.

Guarded by counting the largest bucket in the headless report. A number that
climbs is the warning; a stall is what happens if nobody looks.

## The documents drift from the numbers

Every balance number lives in the creature table or the maze parameters, and no
document restates one. Documents name the field. The moment a page says "balls
roll at four cells a second", that page is wrong the first time anybody tunes it,
and it will be believed anyway because it is written down.

The document validator checks that the pages and the issues agree with each other
about which files and which fields exist. It cannot check prose, and prose is
where this rots.

## Phase seven is a rewrite instead of an addition

[The delve](021-the-delve.md) claims to reuse everything and add only rows.
If it turns out to need the stone changed, or the tick reordered, or the
locomotion table's shape altered — that is a finding about the earlier design
rather than a requirement of the later one, and it is worth stopping over rather
than working around.

## Related documents and tools

- [Open questions](026-open-questions.md) — what is not decided, as opposed to what might break
- `./run-tests` — most of the guards above
