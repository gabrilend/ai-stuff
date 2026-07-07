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

Nothing exists. `src/` holds only a placeholder. There is no window, no main
loop, no chosen framework, and no decision on record about how the game reaches a
screen, a clock, or an input device. Every later Phase 1 issue is blocked on this
choice being made and written down.

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
- **The recommendation (top = most likely to succeed):** build on **LÖVE now**
  for fast iteration, but keep the engine speaking only to a **Platform seam** —
  a module exposing exactly four verbs: *open a drawing surface*, *report the
  current time*, *drain raw input events*, *blit a pixel buffer to the screen*.
  The engine never names LÖVE directly. Because our renderer is our own software
  rasterizer (issue `104`), the framework only has to hand us a surface to blit,
  a clock, and input — all four verbs. That makes the framework genuinely
  swappable: Phase 9 can drop an SDL+FFI Platform behind the same four verbs
  without touching engine code, honouring the roadmap's "packaging and porting,
  not rewriting" promise.
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
