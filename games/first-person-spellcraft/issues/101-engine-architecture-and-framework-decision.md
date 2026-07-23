# 101 — Engine Architecture & Framework Decision

> **Phase:** 1 (Engine Foundation) · **Depends on:** nothing — this is the taproot
> · **Blocks:** every other Phase 1 issue (`102`–`107`) and, through them, all
> later phases · **Difficulty:** medium (mostly decision + a thin seam, little
> code) · **Kind:** architecture-decision issue.

This is the first choice the project makes and the one hardest to unmake, so it
gets the lowest id. It decides *what the engine runs on* and — more importantly —
decides that **the answer must not be load-bearing**, so it can be changed later
without a rewrite.

## Current Behavior

The decision is made and recorded (see Intended Behavior): the engine is a
**pure-C SoraMech-style dataflow substrate** — C boxes that fire when their input
slots are ready, values carried through shared-memory ring-buffer slots, a
re-arming frame-clock box as the heartbeat, all on one worker pool (no Lua, no
FFI) — rendered by **raylib** from a data-driven scene, with a dedicated,
always-unblocked render thread reading a FIFO slot.

The foundation is built and tested: the C slot store at
`libs/engine-core/slot.{c,h}` — three flavors (FIFO queue for drain-and-sum,
latest-wins for the render blackboard, atomic fan-out counter), with a per-slot
spinlock + atomic counter modelled on SoraMech's `009-slot-store.c`. Its
regression prover (`slot-test.c`) passes the single-thread contract plus two
threaded tests: exactness under 8 concurrent producers, and zero torn reads under
concurrent writers. The pure-Lua reference that prototyped this contract has been
translated into that C store and removed. Still to build: vendor the worker pool,
the lean C trigger-on-ready dispatch (+ iterator re-arm, frame-clock heartbeat),
the dedicated render thread, the C boxes, and the story-structured `main()`. No
window or loop runs yet.

## Intended Behavior

A recorded decision, plus a thin **Platform seam** that embodies it:

- **The decision.** Weigh the realistic ways a LuaJIT program reaches a screen on
  both a dev machine and the reach target (an Anbernic handheld — ARM, limited
  CPU/GPU/RAM, running a Linux firmware such as ArkOS / Rocknix / muOS):
  - **LÖVE (love2d)** — already LuaJIT under the hood, so no syntax rewrite is
    ever forced; gives window, timing, input, image, and drawing out of the box;
    can blit a software-rendered pixel buffer as one textured quad. Heavier
    runtime; landing it on a given Anbernic firmware depends on that firmware.
  - **Custom SDL2 + LuaJIT-FFI** — minimal dependency, direct surface/framebuffer
    control, leanest on constrained hardware; SDL2 ships on most Anbernic Linux
    firmwares. Costs us hand-writing the window/timing/input plumbing through FFI.
  - **Raw framebuffer (DRM/KMS) + evdev via FFI** — leanest possible, most
    firmware-fragile; noted as a fallback target, not a starting point.
- **The decision (recorded 2026-07-21, superseding the LÖVE recommendation now
  kept on record below):** the engine is a **SoraMech-style dataflow substrate**
  rendered by **raylib**.
  - *Substrate.* Not a plain fixed-timestep loop but a graph of **boxes** that
    fire when their input **slots** are ready, values carried through per-port
    **ring buffers**, driven by a **re-arming frame-clock box** — the heartbeat
    that keeps the map from quiescing. The game is therefore a long-running
    circular SoraMech map; issue `102`'s "loop" is that heartbeat box, not a
    hand-rolled `while`.
  - *Platform = raylib.* raylib builds a **data-driven scene** from the world's
    positions, replacing the hand-written software column rasterizer. Issue `104`
    shifts from "column rasterizer + framebuffer" to "feed raylib a culled
    renderables list" — issues `104a`/`104b` are to be revised to match.
  - *One language: pure C.* The whole engine is C — no Lua orchestration layer,
    no FFI bridge. This consciously overrides the project's usual LuaJIT default
    (the user's call) so that **everything is a SoraMech box** with no bespoke
    threads outside the box/pool model. It also fits the narrative-`main()`
    methodology of `notes/note-to-claude-ai`, which is already C-flavored (it
    speaks of addresses and "a step beyond could be assembly").
  - *Threads.* All work is C boxes on one worker pool, with **one deliberate
    exception**: the renderer. GL affinity — raylib's context is bound to the
    thread that created the window — forces one dedicated **render thread** that
    owns GL and runs an **always-unblocked** draw loop as fast as it can. It
    reads renderables from the graph through a **FIFO queue slot** with a
    non-blocking pop, and is allowed to lag the pool by a task or two (invisible
    at frame rate). We chose this over pinning a render *box* to a worker: a
    dead-simple always-running thread beats adding affinity machinery to the
    pool. Values cross between boxes through shared-memory slots
    (`libs/engine-core/slot.c`); the read never tears because a slot copies a
    whole struct under its lock. See
    [`docs/soramech-notes.md`](../docs/soramech-notes.md).
  - *The Platform seam survives.* The engine still speaks to a thin seam (open a
    surface, report time, drain input, present a frame); raylib is merely its
    first implementation, so a later SDL/framebuffer backend stays swappable. The
    LÖVE / SDL / raw-framebuffer options above remain on record as alternatives
    behind that seam.
- **The earlier recommendation (superseded, kept on record per this issue's own
  instruction to preserve losing options):** build on **LÖVE now** for fast
  iteration behind the same four-verb Platform seam. Recorded so the choice can
  be re-litigated with context if raylib proves wrong on the Anbernic target.
- **No fallbacks.** If the chosen platform library is absent or fails to open a
  surface, the Platform module **errors loudly and stops** — it does not quietly
  degrade to a headless or stub mode (a fallback is a warning; a warning is an
  error). Any deliberate stub (e.g. a headless test Platform) must announce
  itself on every use.

## Suggested Implementation Steps

1. Write the decision down as a short architecture-decision section in
   `docs/datapath-engine-foundation.md` (the Platform bullet already stubs this):
   which framework, why, and the swappable-seam rationale. Keep the losing
   options recorded so the choice can be re-litigated with context later.
2. Define the **Platform seam** as an interface first (list the four verbs and
   their inputs/outputs in a `.info.md`), before any implementation. The seam is
   the deliverable; the LÖVE binding is just its first implementation.
3. Implement one concrete Platform backed by the chosen framework, satisfying the
   four verbs and nothing more. Give it the indexed filename + `.info.md`
   companion + vimfolds the house style requires.
4. Prove it with the smallest possible program: open a surface, blit a solid
   colour, read one key, close cleanly. This throwaway prover can be a temporary
   script (mark it `-done` for one commit if it has no future use, per house
   rule) — or promoted into the issue `102` loop.
5. Confirm the syntax stays LuaJIT-compatible (no Lua-5.4-only constructs) so the
   door to the Anbernic/SDL path stays open.

## Related Documents / Tools

- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — the
  Platform structure and the Platform seam (Phase 9) description.
- [roadmap.md](../docs/roadmap.md) — Phase 9's promise that constraints honoured
  here mean packaging, not rewriting.
- Consumers of this decision: issue `102` (loop drives Platform timing/blit),
  `104` (renderer targets the Framebuffer that Platform blits).
