# 206 — Source-agnostic input abstraction layer

> **Phase:** 2 — Dual-Mouse Aiming & Input — **CAPSTONE**
> **Difficulty:** medium-hard (it is small code, but it is the load-bearing seam
> for three later phases — get the contract wrong and everything downstream pays)
> **Depends on / blockers:** [204](204-dual-grip-aim-geometry.md) (an aim result to
> wrap), [205](205-hand-animation-from-dual-input.md) (a pose channel to expose),
> and through them the whole 201→205 chain; Phase 1 loop to drive the per-tick
> update.
> **Blocks (out of phase):** Phase 3 aimed spells, Phase 5 NCP takeover, Phase 9
> gamepad, and the stretch 207 all plug into the interface this issue defines.

## Current Behavior

None of this exists yet — greenfield. The dual-mouse pipeline (201→205) can
produce an aim, but every would-be consumer would have to reach *into* it and know
about mice, grips, and evdev. That coupling would make it impossible for a
gamepad, an AI, or a BCI to aim the same game without rewriting spells.

## Intended Behavior

This is **the** deliverable of Phase 2: a single, source-agnostic way to ask
"where is the player aiming, and what do they want to do?" — regardless of what
produced the answer. It has three parts:

1. **The canonical aim state (the data contract).** One struct every source
   produces and every consumer reads:
   - **Aim orientation** — the world-space direction (and roll) a spell fires
     along, composed from 204's player-local aim result and the player's facing.
   - **Discrete intents** — normalized, source-independent signals: fire,
     begin-charge, release, alt (extend as spells demand). Decoupled from any
     physical button so a stick or an AI can raise them identically.
   - **Per-hand pose channel** — 205's renderer-ready hand/wand poses, so the
     hands are always drawable no matter the source.
   - **Source tag** — which source produced this frame, for HUD and debugging.

2. **The aim-source interface (the contract every producer implements).**
   - **advance-one-tick(dt)** → produce the current aim state.
   - **activate / deactivate** → acquire and *release* devices. Releasing is not
     optional: switching away from dual-mouse must ungrab the mice (ties to 201a's
     release path) or the desktop is left with two frozen pointers.
   - **descriptor** → identity + capabilities (does it provide real per-hand
     poses? real discrete buttons? does it need calibration?). Consumers and the
     HUD read this instead of special-casing source types.

3. **The active-source registry / selector.** Holds every registered source,
   tracks the one active source, routes the Phase 1 loop's per-tick input hook to
   it, and publishes the resulting aim state to consumers. **Runtime switching is
   first-class**: desktop dual-mouse ↔ gamepad ↔ AI takeover, via
   deactivate-old-then-activate-new. Source selection is a dispatch/registry
   lookup, not an if/else ladder over source types (project convention: index
   behavior, don't branch on it).

The dual-mouse pipeline is registered as the **first concrete source**, wrapping
201→205 behind this interface. It is one implementation among the several the
later phases will add — deliberately *not* privileged in the interface.

## Suggested Implementation Steps

1. **Define the aim-state struct** (orientation, discrete-intent set, pose
   channel, source tag). Keep it primitives + small structs.
2. **Define the source interface** as a table-of-functions contract (advance,
   activate, deactivate, descriptor). Document each method's obligations,
   especially that deactivate must release all held devices.
3. **Build the registry/selector:** register a source, list sources, get/set the
   active source (deactivate outgoing, activate incoming), and the per-tick
   `update → publish` the loop calls. Store sources in a keyed table; selection is
   a lookup.
4. **Implement the dual-mouse source** as an adapter: on activate it opens+grabs
   the two mice (201a) and starts the read loop (201b); each advance runs the
   drain → per-hand state (202/203) → geometry (204) → pose (205) chain and packs
   the results, composing player-local aim with player facing for world-space
   orientation; on deactivate it releases the mice.
5. **Publish to consumers.** Expose the current aim state as the single read
   surface Phase 3 spells and the Phase 1 renderer consume. Document this as the
   seam in the datapath doc.
6. **Prove the seam with a fake source.** Register a **fake source** that emits a
   scripted aim state (fixed direction, scripted fire intents). Assert the
   registry activates/deactivates it, routes updates, and that a downstream reader
   sees the scripted values — with **no hardware and no mouse**. This is the test
   that guarantees Phase 3 and Phase 5 can build against the contract before their
   real sources exist. Per convention, added modes must both be proven working:
   test source-switching between the fake source and (a recorded-trace-backed)
   dual-mouse source, asserting a clean handoff and device release.

## Structures & Functions By Role

- The **aim state** struct (the contract).
- The **aim-source interface** (advance / activate / deactivate / descriptor).
- The **source registry/selector** (register, list, get/set active, per-tick
  update+publish).
- The **dual-mouse source** adapter (wraps 201→205).
- A **fake source** for tests, and a **trace-backed dual-mouse source** variant.

## Design Notes To Record As Comments

- Why this is the capstone and not built first: it is the *convergence* point with
  the most Phase-2 blockers behind it, and it is easier to abstract a real,
  working dual-mouse pipeline than to guess the contract in a vacuum. But the
  contract is designed so 204/205 already produce data in its shape, so wrapping
  is adaptation, not a rewrite.
- Why deactivate must release devices: a grabbed mouse (201a `EVIOCGRAB`) is
  invisible to the whole OS until released; forgetting this on a source switch
  freezes the user's desktop pointer. This is the sharpest footgun in the phase.
- Why intents are decoupled from buttons: Phase 5's AI and Phase 9's gamepad raise
  "fire" without a mouse button existing; the intent set is the shared vocabulary.

## Related Documents / Tools

- Datapath: [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md)
  — stage [5] canonical aim state, the source interface, and the "where other
  phases plug in" seams.
- Wraps: [204](204-dual-grip-aim-geometry.md) and
  [205](205-hand-animation-from-dual-input.md) (and the chain beneath them).
- Consumed by (future): [datapath-spell-system.md](../docs/datapath-spell-system.md)
  (Phase 3) and [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md)
  (Phase 5).
- Extended by: [207 — stretch: BCI + ceiling-headset aim source](207-stretch-bci-ceiling-headset-source.md).
