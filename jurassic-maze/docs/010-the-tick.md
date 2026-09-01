# The Tick

One tick is one sixtieth of a second of simulated time, always, regardless of
how fast the machine is or whether anybody is watching.

## Fixed, and why

The engine hands the viewer a real elapsed time — sometimes a sixtieth of a
second, sometimes a fifth of one because the window was dragged. That number
never reaches the simulation. The viewer accumulates it and spends it in whole
ticks:

    leftover = leftover + elapsed
    while leftover >= TICK do
        world.tick()
        leftover = leftover - TICK
    end

A simulation stepped by a variable timestep produces different results on a fast
machine than on a slow one. For a rolling ball that is not a subtlety — the
integration error in its velocity depends directly on the step size, so a ball
that clears a gap at sixty frames a second falls into it at thirty. Every seed in
every bug report would then mean something different on every machine.

The accumulator has a ceiling. If the window was dragged for two seconds, the
loop does not try to catch up on a hundred and twenty ticks in one frame — it
discards the excess and the simulation is simply behind. Trying to catch up is
the spiral of death: the catch-up takes longer than real time, which produces
more to catch up on.

## The passes, and the order they run in

A tick is a sequence of named passes. Each one sweeps the whole body store doing
one thing, and finishes before the next begins.

| Pass | What it does |
| --- | --- |
| **decide** | every body asks its brain what it wants. Writes intentions, touches nothing else. |
| **move** | every body's locomotion advances it. The one pass that changes positions. |
| **settle** | falling bodies land, stances are brought back into agreement with positions, anybody who left the world is caught |
| **meet** | bodies that ended up near each other are paired off. See [two bodies meeting](016-two-bodies-meeting.md). |
| **resolve** | duels exchange blows, damage that was buffered is applied, deaths happen |
| **spawn** | the aquarium is topped up: bodies that left are replaced |
| **index** | the spatial buckets are rebuilt for next tick's `meet` |

The order is not arbitrary and two things about it are load-bearing.

**Deciding is separated from moving** so that no body's decision can depend on
whether another body has moved yet this tick. If they were one pass, body 4's
choice would see body 3 in its new position and body 5 in its old one, and the
simulation would depend on the order bodies happen to be stored in — which
changes every time one dies.

**Damage is buffered and applied in one place.** Two fencers who strike each
other fatally in the same tick both die. If damage applied immediately, whichever
was stored first would kill the other and survive, and the outcome of every duel
would be decided by an array index.

## The passes are a dispatch table

The tick is not a function containing seven calls in a row. It is an array of
`{name, function}` pairs that is walked in order.

Three things fall out of that, and the third is the reason:

1. Adding a pass is adding a row. Phase seven adds `burn`, for
   [things that are on fire](023-the-monsters-of-the-delve.md), and it is one
   row inserted before `resolve`.
2. Timing every pass is a loop around the walk, not seven pieces of timing code.
   The per-pass costs in the headless report come from there.
3. **A pass can be skipped or replaced without editing the tick.** The ball phase
   does not need `meet` or `resolve`, and turning them off is removing rows
   rather than threading a flag through a function.

## Slicing across cores

Each pass is the same arithmetic repeated over many independent bodies, which is
the shape of work that should never run on one thread. A pass declares whether
it is **parallel-safe**: whether two bodies processed at the same time can
possibly touch the same memory.

| Pass | Safe | Why |
| --- | --- | --- |
| decide | yes | writes only to the deciding body's own intention slot |
| move | yes | writes only to the moving body's own position; the stone is read-only |
| settle | yes | same |
| meet | **no** | pairs two bodies, so two threads could pair the same body twice |
| resolve | yes, per pair | pairs are independent of each other once they are formed |
| spawn | **no** | takes ids off a shared free list |
| index | **no** | scatters into shared buckets |

A safe pass is handed to the thread pool as a range of body indices split into
one chunk per core. An unsafe one runs on the calling thread. The unsafe ones are
the three cheapest passes, which is not luck — a pass that has to touch shared
state was designed to be small precisely so that it could be the one that does
not scale.

The parallel-safe flag is per pass and it is stated in the table, not inferred.
Inferring it means being wrong about it silently once, at which point the
simulation stops being deterministic and nobody knows when it started.

## Related documents and tools

- [A body and what it carries](011-a-body-and-what-it-carries.md) — what the passes sweep
- [Locomotion is a dispatch table](012-locomotion-is-a-dispatch-table.md) — the move pass, in detail
- `./run-maze --headless --report` — the per-pass timings
