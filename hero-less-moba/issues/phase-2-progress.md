# Phase 2 Progress — Things That Walk and Fight

**The goal:** the soldier. One record, one brain, one combat system, used by
everything that ever moves. With the heroes subtracted out there is no second
system to distract from a bad one, so this is the phase the game lives or dies by.

**Ends with:** two waves meeting in the middle of a lane and grinding to the
stalemate the vision describes. **Seeing the stalemate is the point** — it is the
problem statement, rendered, and phase 4's demo is the answer to it.

| Issue | | Status |
| --- | --- | --- |
| 201 | A soldier is one record | built |
| 202 | Walking an edge of the graph | built |
| 203 | The brain is five states | built |
| 204 | Choosing what to attack | built |
| 205 | Damage is buffered, then applied | built |
| 206 | The frontline is a queue | ranks built, lane width not — G3 |
| 207 | Waves spawn on a cadence | built |
| 208 | A wave knows when it is gone | built |
| 209 | The thread pool slices the tick | not started — H3 |
| 210 | A death decays before it is final | built |
| 211 | Waypoints, and the zones they sit in | in progress — the umbrella |
| 211a | The lane is cut into zones | built |
| 211b | Every zone holds a waypoint | built — H9 |
| 211c | A formation is a circle that faces where it is going | built |
| 211d | Marching speed is not running speed | gears built; running not |
| 212 | A beaten body gets one roll | not started |
| 213 | What the lane can afford | not started — fully specified |
| 214 | Going round what is in the way | built — and neither of its two designs was |
| 215 | A body has a size | built, except that size does not grow with upgrades |
| 216 | Movement is a goal and a step | in progress — the umbrella |
| 216a | A goal, and a step | built |
| 216b | Every way of moving is a row | built for everything on a road |
| 216c | Three paces, and hurry is faster than marching | built — M5 open |
| 216d | A guard is still an edge walker | not started |

**Blocking:** nothing.

**Carry into the work:**

- **Doubles are fine** — no fixed-point rewrite. Durations stay integer ticks.
- **A kill pays every player on the killing team**, so `last_hit_by` walks back
  to a team rather than to an owner.
- **The front rank is N abreast, not single file**, and the centre lane is wider
  than the sides. That is the only real difference between the three lanes and it
  makes the middle where a body-count advantage converts fastest.

**Demo:** not yet built.

## Where the prototype got to

The soldier is one record, one movement routine, one targeting routine, one attack
routine, and the brain is a dispatch table with a row per state. Waves spawn on a
cadence as a column — captain first, then melee, then ranged — and a wave notices
when it has been wiped without anything scanning every wave every tick.

**The phase's ending is reproduced.** Two waves meet in the middle of a lane and
grind to the stalemate the vision describes, and a headless match with nobody
placing anything runs twenty-two minutes without either side taking a base. Seeing
the stalemate was the point: it is the problem statement, rendered.

**206 is the gap.** Melee bodies form ranks and ranged bodies hold behind them at
their own reach, which is the half of the issue that reads correctly on screen. The
other half — how many bodies a lane's *width* lets stand abreast — is not built at
all, so the centre lane is wider only in the drawing. See G3, which also blocks B1.

**209 is not started, and the plan it was written with does not work.** The tick
runs on one thread. Nothing in the design is in the way of *slicing* it, and it has
not been needed at prototype body counts — a match runs at many times real time, and
the census in the headless report says the field holds hundreds of bodies, not
thousands.

But the mechanism the issue names is coroutines, and coroutines in Lua all run on
one core: they hand control to each other and never hold it at the same time. Over a
tick that is arithmetic from end to end and never waits for anything, that is a more
complicated way to take exactly as long. **Settled for now: the prototype is
single-threaded, and the coroutine pool is the shape of the idea rather than a
working parallelism.** When it needs to scale, the parts that matter move to a C
core. See H3.

**210 is built, and it changes what death is.** A body at zero health leaves the
field immediately and then **decays for two seconds**, holding its slot and every one
of its numbers, before anything about the death is made final. Nobody is paid, no
wave counter moves, no guard is replaced and no challenge ends until the decay runs
out.

The reason is a hole the replay log found: a body that died on one machine and did
not die on another can never be corrected, because the slot has been recycled and
there is nothing left to write onto. Deaths are the hinge everything hangs from —
health makes deaths, deaths make wipes, wipes make draws, draws make the chest — so
one soldier's difference puts a machine permanently out of step. Two seconds is two
reconciliation cycles, which is long enough for every machine to have had its say.

The cost is real and worth naming: **every consequence of a death lands two seconds
late**, uniformly, so it is a delay rather than a distortion. Paying immediately and
undoing it later was the alternative and it does not survive contact — a payment can
be unmade only if it has not been spent, and a chest draw that has already been
placed cannot be unmade at all.

The implementation is one number and one gate. `alive` is what everything in the
simulation already tests, so setting it to zero the instant a body falls is what
makes a decaying body stop fighting, stop being a target, stop holding a place in
the queue and stop counting toward push depth — with no change to any of those
passes. Which is the whole argument for having one flag everything agrees on.

It also happens to be the better thing to look at: a body that fades rather than
blinking out is the least artificial version of the moment, and the data behind the
fade is real rather than invented by the renderer.

**211 is in progress, decided, and split into four.** A lane's measure of how far
along a wave has got becomes four times finer, and a wave approaches **waypoints** —
points at random positions inside each of those finer stretches — rather than simply
advancing a number, so its angle of approach varies and two waves walking the same
road do not tread in the same places.

Both questions came back, and the second came back bigger than it was asked. The
finer measure sits **underneath** the milestones rather than replacing them, so no
tower moves and nothing that says "milestone" changes meaning.

And a waypoint neither steers nor navigates, because **a formation stops being a
wide thing at a distance and becomes an oriented disc**: its position is the centre
of its bodies rather than the front of them, its radius is exactly half its width,
its diameter is the face of the line, and it turns to point at what it is walking
toward. What it points at, when there is an enemy, is the enemy's **frontline** —
their diameter displaced forward — rather than the middle of their block, because
the middle of a block is behind the people who will actually be hit.

Two things fell out of that and became their own work. A disc that rotates moves a
body's intended place out from under it, so the cohesion clamps have to open. And
**marching speed is not running speed** — two numbers about a body rather than one
with a modifier, with nothing running while it chases a kill.

**212 is the mechanic that arrived attached to the last of those, and it is the
sharpest thing in the phase.** A beaten body rolls once. Failing the roll lets it
run away and live; passing it makes it stay, land one single blow, and die. That
inversion is deliberate: the save is against self-preservation, not against fear.
And it is how anything large dies — a monster is brought down by the accumulated
last blows of everything it beat, which makes the Eternal Golem's deathlessness a
statement about scale rather than about a number.

**The map was resized alongside it** and is written up in the balance ledger rather
than here: bodies further apart, drawn smaller, roads wider — and the map checker
now refuses a map whose roads no longer carry the number of bodies abreast that the
shape file says they should.

## Bodies stopped being able to stand in the same place, and four things fell out

The ruling on H16 is that **units never walk through each other**, enforced one way:
before a body moves, the ground its next step lands on is checked against everything
near it, and if it is inside somebody it is moved to that body's near face. Both of the
designs 214 was going to build and compare — swarm pathfinding, and formations giving
way to formations as bodies — were dropped without being built, because fifteen bodies
each declining to stand inside somebody *is* a formation flowing round another one.

**It could not be built without giving bodies sizes**, which was 215 and had been
sitting behind it. Three numbers that had been allowed to disagree became one: the
renderer's drawing table, the single `personal_space` every body shared, and the sight
width that was a fifth of that. The fifth turned out to be 3.6 — exactly the melee
body's drawn radius — so it had been tuned to the picture all along and written as a
fraction of something else.

**Reach had to start measuring to a body's skin.** A soldier stops against a monster at
thirty paces from its centre and its sword reaches seventeen. Measured centre to centre,
every melee body in the game misses every monster forever, and what that looks like from
outside is not a combat bug: it is a challenge phase that never ends, a calm that never
begins, and no boon ever offered.

### Three things learned, each of them the hard way

**The rule is about the step, not the destination.** A marching body's formation slot
can be ninety paces off, and whether somebody is standing on it is a question about the
future. Asked about the slot, bodies were shoved off their places for obstacles they
were nowhere near; the line stopped dressing, and since a wave's anchor waits for its
own stragglers, waves stopped advancing. Matches went from running the three-challenge
arc nine times in ten to almost never — decided instead by a base falling during the
first challenge. Same rule, one word different about where it is asked.

**Two bodies must never be *born* in one place**, because nothing can separate them
afterwards: bodies at one point have no direction to be pushed apart along. Two spawners
had been doing it since they were written, invisibly, and only became visible once
overlapping was forbidden. Every tower put all its guards on the tower's own node. And a
wave deeper than its start distance had its rear ranks placed behind the library, which
clamps to zero — and zero is the node **all three lanes share**, so the back of every
wave leaving a base was born inside the back of the other two.

**An offset must be expressed in a frame belonging to the thing it is offset from.** The
guards were first spread on a spiral in world coordinates, which is a fixed set of
absolute directions. The map is a mirror, so that put one team's guards a pace toward
the enemy and the other team's a pace toward home. Four matches with nobody playing, and
the same side won all four. The axis now runs from that team's library to that tower, so
it mirrors when the tower does.

### What the queue turned out to be for

Deleting the frontline queue and keeping only the physical rule was built and measured,
and it does not work. Bodies press to touching, a losing wave spreads out and is killed
piecemeal instead of stiffening into a block, and attrition stops self-correcting. The
two rules are not versions of each other: one asks *may I stand here* about everything
on the field at two bodies' widths, and the other asks *should I push past the man in
front of me* about my own side at a rank's spacing. The first cannot make a rank and the
second cannot stop a body standing inside a monster.
