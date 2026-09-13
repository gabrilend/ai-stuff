# 003 — The Tick and the Timers

The heartbeat, and the one shape every periodic effect in the game takes.

## The tick

The simulation advances in **ticks**. A tick is the only unit of time the rules
know; seconds exist in the catalogue tables (a heal interval is written down in
seconds because a person tunes it in seconds) and are converted to ticks once, at
load. Nothing in a rule reads a clock.

One tick is one pass over an **ordered table of systems**. The order is data — an
array of functions — rather than a function body, so the order of the simulation
can be read, printed, and tested. The systems, in order:

1. **Commands.** Every command stamped for this tick is applied, in the order it
   was queued. See [the command door](011-other-players.md).
2. **Income.** Mass from held cells, energy from standing energy buildings.
3. **Construction.** Every line and building under construction draws its share
   of mass, energy, and build power for this tick, and finishes if it is done.
4. **Emit.** A finished unit leaves its factory carrying a copy of the pattern.
5. **Move.** Every unit takes one step along its pattern, its flight, or its
   mission.
6. **Claim.** Territory under and around each unit is painted.
7. **Sight and aim.** Every shooter that is reloaded picks a target it can see.
8. **Fire.** Each shot is scheduled to arrive at a later tick, by distance.
9. **Land.** Every shot whose arrival tick is now is applied, in a fixed order.
10. **Die.** Units at or below zero become bones.
11. **The cloud.** If the cloud's round counter fires this tick, one round of the
    air battle is resolved.
12. **Consequences.** Ground that changed hands this tick hurts the roster and
    spends thorns.
13. **Snapshot.** The world is fingerprinted, and copied out for the viewer if one
    is attached.

Adding a system is adding a row. Reordering is reordering rows. A system that is
not in the table does not run, and there is no other way to run one.

## Every periodic effect is a pair of integers

The vision describes how tanks heal, and then says the whole game works that way.
Here is the mechanism, stated once so every system can point at it.

A **periodic effect** is a global counter with a period. `heal.tank` fires every
so many ticks; when it fires, its **increment** goes up by one. That is all the
counter does. It does not walk the tanks. It does not touch anything.

A unit that is subject to the effect stores **two integers**: a value, and the
increment at which the value was last written. The current value is derived when
somebody asks for it:

    current = min(cap, written_value + (increment_now - increment_written))

Four operations. When something changes the value from outside — a shell lands —
the current value is derived, the change applied, and the pair rewritten with
the increment of now. Nothing is ever iterated. A thousand tanks healing costs
exactly what one tank healing costs, which is nothing until it is looked at.

This is the vision's "units keep track of the increment they were started at ...
and compare it to the increment that is now," and it is why the vision says the
design is *perfect for soramech*: a derivation from three integers is a pure
function of its inputs with no memory, which is precisely what a box is allowed
to be. See [the handheld](012-the-handheld.md).

**Every** periodic effect uses this shape. The list at the moment of writing:

| Effect | Per | What the pair holds |
| --- | --- | --- |
| heal | unit kind | health, and when it was last written |
| reload | weapon kind | whether the weapon may fire: fired-at increment against now |
| shield recharge | enforcer | shield strength, and when it last took a hit |
| roster recovery | roster kind | an engineer's health, and when it was last hurt |
| the cloud's round | the cloud | which round is current; planes store the round they joined |
| the claim | territory | a cell stores the increment its claim began; a claim completes when enough have passed |
| the plane's launch | command truck | when the last plane left; the next may leave when enough have passed |
| the discovery broadcast | the network | when a peer was last heard; aged out when enough have passed |

Each kind of unit heals on **its own counter**, so tanks and anti-air guns and
planes each recover on a different rhythm, and adding a kind is adding a counter.
The intervals live in the catalogue, not here.

<!-- toy: timer -->

## Determinism

The same seed and the same commands produce the same match, tick for tick, on
every machine. That is not a nicety; it is the [network model](011-other-players.md).
Three rules keep it true:

- **Randomness comes from named streams.** Every random draw names the stream it
  is from — `dunes`, `roster-hurt`, `cloud-round`, `report-order` — and each
  stream is seeded from the match seed and its own name. A new random use is a
  new stream; nothing ever reaches for a global generator.
- **Iteration order is array order.** Every collection the tick walks is a flat
  array walked from one to its length. Nothing iterates a hash table whose order
  the language does not promise.
- **Arithmetic is integer where it can be, and where it cannot, every machine does
  the same double-precision operations in the same order.** Positions are
  doubles; durations are ticks. Whether doubles are safe across the two machines
  this game targets is an [open question](016-open-questions.md) marked awaiting
  evidence, and the reproducibility test is what will answer it.

## The thread pool

The tick is sliced across a pool of workers. Which systems are sliceable is a
property of the data they touch: move, sight-and-aim, and fire each read the
world and write only their own unit's row, so they slice by unit range; land,
die, and claim write shared state and run on one worker in a fixed order. The
pool is not an optimisation to add later; it is the shape the simulation is
written in from the first system, because a program that was single-threaded
first has a hundred quiet assumptions that a pool breaks one at a time.

The rule the pool enforces: **a sliced system may read anything and write only
its own slice.** A system that needs to write elsewhere buffers what it wants to
write and a later, unsliced system applies the buffer. Damage is the model — a
shot is buffered at fire time and applied at land time, in order.

## The snapshot

At the end of every tick the world is **fingerprinted** — a hash of every unit's
position and health, every cell's owner, and the economy's totals — so that two
machines can compare a single number and know whether they agree. And if a viewer
is attached, the world is **copied** out to it, whole. The viewer never reads the
live world; see [the views](010-the-views.md).

Related: [a unit](004-a-unit-and-what-it-carries.md) ·
[other players](011-other-players.md) · [the shape of the code](013-the-shape-of-the-code.md)
