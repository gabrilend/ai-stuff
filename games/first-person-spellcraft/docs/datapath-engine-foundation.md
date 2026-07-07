# Datapath — Engine Foundation (Phase 1)

> How data flows through the Doom-style engine that everything else sits on. This
> is a **living design doc**: as the Phase 1 issue files (`issues/101`–`issues/107`)
> are implemented, update the structures and seams described here to match what
> was actually built. Where this doc and the [vision](../notes/vision) disagree,
> the vision wins.
>
> Back to the [table of contents](table-of-contents.md) · phase plan in the
> [roadmap](roadmap.md) · feature context in the [vision overview](vision-overview.md).

---

## What this phase is

The taproot. A player can stand in a square room, look around a Doom-style
first-person view, walk into a wall and be stopped, jump onto a ledge, and pass
through a door into the next square room. Nothing about spells, mice, puzzles, or
dungeon masters lives here — but every one of those later phases plugs into a
**seam** this phase exposes. This doc names the data, the transforms that move
it, and those seams.

The capability is drawn from the vision (~lines 116–122): *"the engine can be
similar to Doom, where there's square rooms that each have something special
about them, and the characters move around semi-quickly and have to do
platforming puzzles."* Three load-bearing phrases: **square rooms**, **something
special about each**, **platforming** (so the world has real verticality).

---

## The one-run data flow

The whole engine is one river from `input/` to `output/goodbye`. Per project
convention the **first** act is to read `input/`, and the **last** act is to
write `output/goodbye`.

```
  input/startup ──read──▶ RunConfig ──▶ Platform.init (window, timing, input, blit)
                                             │
                                             ▼
                              World (built or loaded from RunConfig.world)
                                             │
        ┌────────────────────────────────────┴───────────────────┐
        ▼                                                         ▼
   Player state                                            fixed-timestep LOOP
   (spawn from World)                                             │
        │        ┌──────────────── each fixed tick ──────────────┤
        │        ▼                                               │
        │   poll input  ──▶ IntentFrame ─▶ movement+collision ─▶ gravity/vertical
        │                                        │                │
        └────────────────────────────────────────┴────────────────┤
                                                                   ▼
                                            each frame: RENDER (World + Camera → Framebuffer)
                                                                   │
                                                                   ▼
                                                        Platform.blit(Framebuffer → screen)
                                             │
                        loop exits (quit intent) ─────────────────┘
                                             ▼
                                   write output/goodbye  ──▶ done
```

Read left-to-right: configuration seeds the world, the world seeds the player,
the loop turns input into motion and motion plus the world into pixels, and the
run ends by saying goodbye. Each arrow is a transform listed below.

---

## Key data structures (by role)

Listed by the role they play, not by their eventual code names. Prefer plain
structs of primitives over frameworks (project house style).

- **RunConfig** — the parsed contents of `input/startup`. Which world map to
  load, the input mode (`dual-mouse` / `single-mouse` / stretch `bci`), and the
  role (`player` / `ncp`). Produced once at boot; read-only thereafter. It is the
  single answer to "how do I start up this run."

- **Platform** — the thin seam between the engine and whatever windowing/timing/
  input/blit library is underneath (LÖVE now, possibly SDL+LuaJIT-FFI later). It
  offers exactly four verbs the engine needs — *open a surface*, *tell me the
  time*, *give me raw input events*, *blit this pixel buffer to the screen* — and
  nothing else. The engine never names the underlying library directly, so the
  library is swappable without touching engine code. See issue `101`.

- **World** — the map. Held as **two views of one thing**:
  - a **tile grid** (2-D array of cells) that the raycaster marches and collision
    tests against. Each cell carries: solid-or-empty, wall surface id, **floor
    height**, **ceiling height**, and the **room id** it belongs to.
  - a **room table** keyed by room id, holding each room's **special property**
    (the "something special about it") and its **door list** (connections to
    other rooms). This is the handle the Dungeon Master (Phase 6) populates and
    that Phase 4 puzzles attach to.
  The grid is what the renderer and collision walk; the room table is what
  gameplay reasons about. Same map, two lenses.

- **Room** — one square region: id, its footprint in the grid, its floor/ceiling
  heights, its special-property tag, and its doors. The special-property tag is
  an index into a **dispatch table** of room behaviours (dispatch over if-else,
  per house style) — Phase 1 ships only trivial entries (plain, spawn); later
  phases register puzzle/trap/combat/treasure behaviours against the same table.

- **Door / Connection** — a link between two rooms through a specific grid edge:
  which two rooms, where the opening is, and whether it is currently passable.
  The graph edges over the room nodes.

- **Player** — the moving observer: horizontal position (x, y in tile units),
  **height above the floor (z)**, facing angle (yaw), look angle (pitch, needed
  so verticality reads on screen), horizontal velocity, **vertical velocity**,
  and an **on-ground** flag. Movement writes velocity; collision and gravity
  correct position; render reads position + yaw + pitch + z.

- **Camera** — the projection viewpoint derived from the Player each frame:
  eye position (x, y, z + eye-height), yaw, pitch, and field-of-view. Kept
  separate from Player so a future spectator/replay/NCP-possession view can drive
  the camera from something other than the local player.

- **Framebuffer** — the pixel buffer the renderer writes column-by-column and the
  Platform blits. Sized to a small internal resolution (handheld budget) and
  scaled up on blit, so the software rasterizer's pixel cost stays fixed
  regardless of window size.

- **IntentFrame** — one tick's worth of *what the player wants*: move-forward,
  strafe, turn, look, jump, quit — as normalized intents, **not** raw device
  events. The movement systems consume intents, never devices. This indirection
  is the seam Phase 2's input layer slots into (the "aim once, aim everywhere"
  strategem): Phase 1 fills the IntentFrame from a keyboard/single-mouse stub;
  Phase 2 fills the same struct from two mice; nothing downstream changes.

- **EngineState** — the top-level bundle threaded through the loop: Platform,
  World, Player, Camera, Framebuffer, the accumulator/clock for the fixed
  timestep, and a running flag. One value to pass, so the loop stays legible.

---

## The transforms (systems, by role)

Each is a small system that reads some of the above and writes some of it. Named
by role; real code uses indexed filenames + `.info.md` companions + vimfolds.

1. **Read startup** — parse `input/startup` into RunConfig. First act of the
   program. If a required key is missing, **error loudly** — no silent defaults
   (fallbacks are warnings, warnings are errors, per house rule).
2. **Init platform** — open the surface/window, start the clock, open input,
   allocate the Framebuffer. Errors out (does not fall back) if the platform
   library is absent.
3. **Build / load world** — turn RunConfig.world into a World (both views). Phase
   1 may build a hand-authored test map in code; the format is designed so the
   Phase 6 Dungeon Master can emit the same structure.
4. **Spawn player** — place the Player at the world's spawn room, feet on that
   room's floor height.
5. **Fixed-timestep loop** — accumulate real time, step the simulation in fixed
   increments (deterministic motion + stable collision), render once per display
   frame with interpolation. Heartbeat of issue `102`.
6. **Poll input → IntentFrame** — pull raw events from Platform, translate to
   normalized intents. The stub lives here in Phase 1; Phase 2 replaces the
   translator, not the loop.
7. **Movement + collision (horizontal)** — apply horizontal intent to velocity,
   integrate position, resolve against wall cells so the player slides along
   walls instead of stopping dead. Issue `105`.
8. **Gravity + vertical (platforming)** — apply gravity to vertical velocity,
   integrate z, resolve against the current cell's floor/ceiling heights, set the
   on-ground flag, and let jump intent launch only when grounded. Issue `106`.
9. **Render** — from World + Camera, cast columns, draw wall/floor/ceiling into
   the Framebuffer, honouring per-cell floor/ceiling heights (so ledges and drops
   read correctly) and pitch (so looking up/down works). Issues `104a`/`104b`.
10. **Blit** — Platform scales the Framebuffer to the screen.
11. **Write goodbye** — on loop exit, write `output/goodbye`. Final act.

---

## Seams other phases plug into

These are the *interfaces this phase exposes*; the other phases design their own
internals behind them.

- **Input seam (Phase 2).** The IntentFrame + the poll-input transform. Phase 2
  swaps the raw-event→intent translator to read two mice and animate two hands;
  the loop and the movement systems keep consuming the same IntentFrame. This is
  the "aim once, aim everywhere" strategem's anchor.
- **Spell-effect render seam (Phase 3).** The render pipeline exposes a hook
  after world geometry and before the final blit where an effects pass can draw
  into the same Framebuffer (projectiles, glows, hand overlays). Phase 1 leaves
  the hook empty.
- **Room special-property seam (Phase 4).** The room-behaviour dispatch table and
  the per-cell special-tile flag. Phase 4 registers puzzle/mechanism/trap
  behaviours against room ids and tiles; the engine only provides the table and
  the enter/step/exit callbacks it fires — it does not know what a puzzle is.
- **World-population seam (Phase 6).** The World structure (both views) is
  designed to be *emitted*, not just hand-authored, so the Dungeon Master can
  generate a lair (~3 puzzles + 4 combats) as a World the engine loads unchanged.
- **Platform seam (Phase 9).** The Platform abstraction is what lets the Anbernic
  port swap LÖVE for SDL+FFI without rewriting the engine, honouring the
  roadmap's "packaging and porting, not rewriting" promise.

---

## Data lifecycle & ownership

- **RunConfig** is born from `input/startup`, lives read-only for the whole run.
- **World** is built once, mutated only through the room/door seams (a door
  opening, a special tile toggling) — never rebuilt mid-run in Phase 1.
- **Player / Camera / Framebuffer** are per-run, rewritten every tick/frame.
- **Ephemeral logs** go to the project-local `tmp/` symlink (a RAM-backed
  `/tmp/` directory), created by the run script before the loop starts.

---

## Conventions this phase inherits

- **Language:** Lua, LuaJIT-compatible syntax only; no Lua-5.4-only constructs.
- **Files as a story:** each source file carries a numeric index prefix (tracked
  by `.file-index-counter`) and a `filename.info.md` companion listing its usable
  functions and their inputs/outputs. Prefer reading the `.info.md` over the code.
- **Vimfolds:** every function opens with a `-- {{{ name()` comment, then its
  definition, and closes the fold on its own line.
- **Dispatch over branches:** room special properties, input-event handling, and
  render surface selection are dispatch tables, not if-else chains.
- **No fallbacks:** prefer a loud error over a silent default; a fallback is a
  warning and a warning is an error.
- **Scripts run from anywhere:** any run/demo script hard-codes a `${DIR}` at the
  top, overridable by argument, with all paths relative to it.
- **First read `input/`, last write `output/goodbye`.**

---

## A note on counts

This doc deliberately hardcodes no resolutions, tick rates, FOV values, tile
sizes, or map dimensions — those rot. When a Phase 1 statistics/validator utility
exists (e.g. a script that reports the engine's actual internal resolution, tick
rate, and loaded map size), link it here and read from it instead of restating
numbers.

---

## Phase 1 issues that realise this datapath

- `101` — engine architecture & framework decision (the Platform seam).
- `102` — core game loop & program lifecycle (input→loop→goodbye).
- `103` — square-room world data model (the two-views World).
- `104a` / `104b` — the Doom-style renderer (model decision + column rasterizer).
- `105` — player movement & wall collision.
- `106` — platforming: gravity, jumping, vertical collision.
- `107` — engine seams & the Phase 1 capstone demo.
