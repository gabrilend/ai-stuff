<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10;
     reworked the same day when the owner chose soramech as the program's
     shape. Keep it in step with the source. -->

# Architecture

## Platform

LÖVE 11.5 running on LuaJIT. All code is LuaJIT-compatible Lua (Lua 5.1
syntax plus LuaJIT extensions; nothing from Lua 5.3 or 5.4: no `//`
integer division, no `&` `|` `~` `<<` `>>` operators (use the `bit`
library), no `<const>` or `<close>`). Shaders are GLSL as LÖVE accepts it.

## The shape: soramech

The program is built the soramech way — the owner's design pattern of
consensual coroutines, documented in full at
`/mnt/mtwo/programs/sora/minimal-soramech/docs/` (read 001 to 006). In
short:

- A **box** is a small function that takes its inputs by value and returns
  one value. It remembers nothing between calls.
- A **station** is one placement of a box in a **map** (the wiring diagram).
  It owns input **slots** (small queues), and a list of where its output
  goes.
- **The one rule:** a station runs when, and only when, every one of its input
  slots holds a value. Nothing polls and nothing schedules: whoever delivers
  the last missing input notices the station is ready, takes one value from
  each slot, and puts the invocation (a **task**) into the thread pool. Any
  free worker thread picks it up.
- **State lives on the wires.** To keep a running total, a box's output is
  wired back into its own input. A world tick is a value travelling around a
  loop.
- Three box kinds differ only in where output goes: **plain** (one port,
  copied to every destination), **comparator** (less / equal / greater
  ports), **iterator** (each run sends to the next port in turn).
- No box may block. No fallbacks: a missing wire or unknown box stops the
  program and says why.

"Consensual" is the heart of it: nothing is pushed to run; a station runs
when everything it needs has agreed to arrive.

### Why it suits this game

The game is already shaped like this. A courier is a value travelling down
a wire with a delay. A front's fight cannot resolve until both sides'
moves for the tick have arrived. A vote cannot tally until every seat's
ballot is in. A level-up offer cannot be shown until every side's offer is
rolled. Each of these is a station waiting on its slots — and the waiting is
the parallelism: every direction's combat, every seat's offer, every worker's
batch runs as soon as its inputs are present, on whatever core is free.

### The game's map, broadly

```
  input/ ─▶ [read settings] ─▶ [seed streams] ─┐
                                               ▼
  view commands ─▶ [accept orders] ─▶ [couriers step] ──┐
                                                         ▼
       ┌──── one station per direction ───────▶ [move + fight: N] ─┐
  [tick]─┤                                     [move + fight: E] ─┤
   ▲   └────────────────────────────────────▶ [move + fight: …] ─┤
   │                                                              ▼
   │                                          [settle quadrant edges]
   │                                                              ▼
   │                         [economy] ◀─ [calendar] ─▶ [votes when due]
   │                                                              ▼
   │                                    [fronts decided?] ─▶ [level-ups]
   │                                                              ▼
   └──────────────────── world loops back ◀─────────── [snapshot] ─▶ view
```

Each bracket is a station. The world value circulates; per-direction work
fans out because the wiring fans out.

### Determinism

The same seed and the same commands must always produce the same world —
that is what networked play (lockstep) and replays rest on. Soramech runs
stations in whatever order workers pick them up, so determinism comes from
the wiring, not the timing: every random draw comes from a stream named by
(seed, tick, station), and the join stations combine their inputs in a fixed
order (by direction index), never in arrival order.

### Implementation route: the ceramic engine (decided 2026-10-10)

The owner: "soramech engine. lua is singlethreaded. build soramech
coroutines. ceramics." The world runs on soramech's C engine — the ceramic
engine — in the copy world-edit-to-execute improved for per-frame work
(`libs/ceramic/`, see its README), and the program takes the **ceramic
shape**: LÖVE's main thread is the render thread only.

- The boxes are C functions (`src/020-ceramic-boxes.c`), wired by a map
  (`src/021-ceramics.map`), compiled by soramech's `serac` with a small host
  surface (`src/022`) into a shared library (`scripts/build-ceramics`), loaded
  through LuaJIT's FFI (`src/023`).
- Each step is two stages: every unit chunk (32 units a task), then every
  cuboid chunk. A stage goes in as one batch; the render thread counts what
  has landed each frame and never waits.
- The world travels by pointer: the host points the engine at the front and
  back blocks before each step; every chunk writes only its own records.
- The Lua stand-in that came first (stations on the main thread, one task
  per unit through LÖVE channels) is retired: it spent the main thread
  handing out and collecting every unit's task (37 frames per second at
  3,000 units).

## Two halves that never touch directly

**Data generation** and **data viewing** stay apart:

- The simulation map (above) owns all game state.
- Its snapshot station hands each tick's numbers to the **view**, which owns
  nothing but what it is shown and draws the newest snapshot, smoothing
  between two.
- The view sends back **commands** (who, what). Commands are the only way the
  view changes anything.

So the simulation runs headless for tests and balance runs, and the view can
be demonstrated against recorded snapshots without a simulation at all.

## Reading order of source

Source files carry a reading-order index (`src/001-...lua`) counted from
`.file-index-counter`, so the program reads like a story from the world's
smallest pieces up to the screen. LÖVE requires two files by exact name —
`main.lua` and `conf.lua` — so those two are thin doors that only load the
indexed files; they carry no logic.

Every source file has a `name.info.md` beside it listing what it offers to
other files.

## Start and end

- The first thing the program does is read `input/` (seed, team size, which
  seats are human, starting tiers). Missing or malformed input is an error,
  not a quiet default.
- The last thing it does is write `output/goodbye`.
- Logs and snapshot recordings go to `tmp/shared-memory/` (RAM). Every run
  script rebuilds the RAM tiers first.

## Datapaths

One per major feature:

- [datapath-world-tick.md](datapath-world-tick.md) — one simulation step.
- [datapath-orders.md](datapath-orders.md) — from two clicks to a stand
  obeying.
- [datapath-accordion-view.md](datapath-accordion-view.md) — from a place on
  the sphere to a pixel, and when stands merge.
- [datapath-production.md](datapath-production.md) — factories, locked paths,
  engineers.
- [datapath-team-vote.md](datapath-team-vote.md) — ballots to spending.
- [datapath-choices.md](datapath-choices.md) — from seed to a level-up offer,
  and enhancements in the tray.
- [datapath-glass-and-metal.md](datapath-glass-and-metal.md) — how a
  dashboard part, a model, or a voxel cloud becomes pixels.
- [datapath-network.md](datapath-network.md) — commands across machines.
