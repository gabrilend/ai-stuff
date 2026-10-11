<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     It describes how the program is put together. Keep it in step with
     the source: when a layer moves, this file moves with it. -->

# Architecture

## Platform

LÖVE 11.5 running on LuaJIT. All code is LuaJIT-compatible Lua (Lua 5.1
syntax plus LuaJIT extensions; nothing from Lua 5.3 or 5.4: no `//`
integer division, no `&` `|` `~` `<<` `>>` operators (use the `bit`
library), no `<const>` or `<close>`). Shaders are GLSL as LÖVE accepts it.

## Two halves that never touch directly

The project is split the way the house rules ask: **data generation** on one
side, **data viewing** on the other, with a narrow handoff between them.

```
  input/ ─▶ setup ─▶ ┌──────────────────────┐   snapshot   ┌─────────────────────┐
                     │  SIMULATION           │ ───────────▶ │  VIEW                │
                     │  (its own thread)     │              │  (LÖVE main thread)  │
                     │  world, ticks, orders,│ ◀─────────── │  wheel, map, dials,  │
                     │  combat, economy,     │   commands   │  glass & metal       │
                     │  votes, choices       │              │  rendering           │
                     └──────────────────────┘              └─────────────────────┘
                                                                    │
                                                         output/goodbye at exit
```

- The **simulation** owns all game state. It runs on a fixed tick (a set
  number of steps per second, independent of frame rate), from a seed, so the
  same seed and the same command list always give the same game. That is
  what later makes networked play (lockstep) and replays possible.
- The **view** owns nothing but what it is shown. Each tick the simulation
  publishes a **snapshot** (a plain table of numbers and strings: positions,
  health, couriers, readout values). The view draws the most recent snapshot,
  smoothing motion between two of them.
- The view sends back **commands**: plain tables like "stand 7, order
  attack-move, target (tier 2.4, angle 1.31)". Commands are the only way the
  view changes anything.
- The two talk over LÖVE thread channels. Nothing else is shared.

This means the simulation can run headless (no window) for tests and
balance runs, and the view can be built and demonstrated against recorded
snapshots without a simulation at all.

## Many threads where the work splits

Combat and movement for different directions do not interact within one tick
except at quadrant edges, so the simulation splits per-tick work across a
pool of worker threads, one batch per direction, and joins the results
before the tick ends. Offer generation (re-rolling until values match)
also runs across workers. See [datapath-world-tick.md](datapath-world-tick.md).

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
- [datapath-orders.md](datapath-orders.md) — from a button press to a stand
  obeying.
- [datapath-accordion-view.md](datapath-accordion-view.md) — from a world
  position to a pixel.
- [datapath-production.md](datapath-production.md) — factories, locked paths,
  engineers.
- [datapath-team-vote.md](datapath-team-vote.md) — ballots to spending.
- [datapath-choices.md](datapath-choices.md) — from seed to a level-up offer.
- [datapath-glass-and-metal.md](datapath-glass-and-metal.md) — how one
  console element becomes pixels.
- [datapath-network.md](datapath-network.md) — commands across machines.
