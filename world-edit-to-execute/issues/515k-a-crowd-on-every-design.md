# Issue 515k: A Crowd on Every Design

**Phase:** 5 - Rendering
**Type:** Implementation (a benchmark and its report)
**Priority:** Medium
**Parent:** 515 (the render graph on the ceramic engine)
**Dependencies:** 405f (the crowd), 515h (the fabricated frame's harness), 515j (the hand-written opponents)

---

## Current Behavior

Nothing of this exists. The ceramic engine has been measured on uniform
work (515a) and on a fabricated frame whose costs were chosen (515h, 515j).
The crowd (405f) is real game work whose cost nobody chose: most units take
a cheap step each tick, a few re-plan their path (about a hundred times the
cost), and which ones changes every tick. It runs in Lua, one unit after
another, each seeing the moves of those before it, so no design can split
it as it stands.

## Intended Behavior

The owner (2026-09-25): "if the engine is designed to be ceramic
eventually, and we wanted to test the engine's capabilities with a
workload that was unpredictable when compared to the other options (job
system, threaded by system, by role, and single threaded), shouldn't we
build it in all of the options to see which one performs better, and more
importantly, to create another HTML page? This one should have gifs. :)"
And, choosing how to make the tick parallel: "I like option 1 because it
unifies the results and allows us to compare the ceramic core engine's
performance metrics against a valid comparison target."

**The tick in two phases** (in the Lua crowd first, which stays the
reference):
- **Decide,** each unit on its own, from where every unit stood at the
  start of the tick: steer, slide, plan (the costly, unpredictable part),
  give way, notice gridlock. A unit changes only its own state; what it
  would do to another unit (a nudge, a neighbour's back-off) becomes a
  request.
- **Settle,** in id order: each proposed step is taken if it is still
  clear of the units already settled this tick, and the requests are
  applied.
- The result depends only on the orders, never on how the decide phase is
  split, so every design must produce the same checksum of every unit's
  position every tick.

**The same crowd in C** (`src/render/ceramic/crowd/`), checked against the
Lua reference on small scenes, then run by:
- **one thread;**
- **by system:** a parallel loop over the units for the decide phase
  (fixed slices, and a shared counter), a barrier, settle on one thread;
- **the job system** from 515j (a job per slice of units, stealing);
- **the ceramic graph:** decide lanes as stations (each reads the tick's
  snapshot, which travels by pointer as large read-only data does, and
  answers with its units' decisions), joined by a settle station.

**Scales:** 500, 2,000 and 5,000 units on a larger map, a few crossings
each, on this machine; mean and worst ticks, the floor (the tick's
longest single decision, and total work over the cores), and each design's
threading code counted.

**The page** (`src/viewers/ceramic-crowd.html`, published as an artifact,
and a case study for soramech as 151 and 153 were): charts in the kit's
colours, and GIFs: the crowd at each scale, drawn by the renderer and put
together with ffmpeg, and each design's workers over a few ticks (who ran
what, when).

## Suggested Implementation Steps

1. The two-phase tick in `runtime/crowd.lua`; the movement tests pass
   again (retuned if need be), and a test that splitting the decide phase
   any way gives the same positions.
2. `crowd.c`, the same logic; a test comparing it with Lua on the test
   scenes.
3. The designs and the harness; checksums compared.
4. The GIFs, the report, the page.

## Acceptance Criteria

- [ ] Every design gives the same checksum at every scale
- [ ] The C crowd matches the Lua reference on the test scenes
- [ ] The page, with GIFs, published; the case study delivered to soramech
- [ ] `.info.md` beside each new source file

## Related Documents

- `issues/405f-units-path-around-units.md`
- `issues/completed/515h-a-frame-as-a-graph.md`
- `issues/completed/515j-stronger-hand-written-opponents.md`
