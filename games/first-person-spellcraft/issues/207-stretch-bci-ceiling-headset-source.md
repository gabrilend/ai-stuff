# 207 — STRETCH: BCI + ceiling-headset aim source (DEFERRED)

> **Phase:** 2 — Dual-Mouse Aiming & Input — **STRETCH GOAL, explicitly deferred**
> **Difficulty:** research / hardware (out of scope for the shipping phase)
> **Depends on / blockers:** [206](206-source-agnostic-input-abstraction-layer.md)
> (this is one more source behind that interface).
> **Status:** DOCUMENTED, NOT SCHEDULED. Do not build during the Phase 2
> time-gate. This file exists so the vision is not lost, per the roadmap's
> "documented, not built" stance and the project's discipline of preserving the
> vision's dreams verbatim.

## The vision, verbatim (sacrosanct)

From [notes/vision](../notes/vision) lines ~8-13:

> then, if the player happens to have a brain-computer interface,
> something that reads common brain patterns like "look up and to the left"
> represented as the player moving their attention upward and leftward
> which moved the headset mounted to the ceiling at just the right tension
>
> (these are all stretch goals)

This is treated as poetry and intent, not a scoped task. It is preserved here so a
future builder can pick it up whole.

## Current Behavior

**Still not a shipping input source, and still unscheduled** — but the *software
half* of the dream has now been **rehearsed as an isolated experimental spike**,
following this issue's own step "validate with a scripted attention trace before any
real hardware." Under `src/experimental-bci/` there is: an **attention-trace
descriptor** (`006`, the coarse-direction vocabulary + decoder/rig tuning + a sample
trace), an **attention decoder** (`007`, held attention → aim yaw/pitch — drifting
up-and-to-the-left as the vision describes, clamped to the neck's limits), a
**ceiling-headset tension model** (`008`, aim → four cable tensions "at just the
right tension," with the mean-stays-at-base invariant tested), and a **scripted-trace
prover + demo** (`009`) driven by `run-bci-experiment.sh`. 12/12 assertions pass, and
the demo writes a daydream report (attention → aim → tensions over time) to the RAM
tier.

Still only a dream (deferred and unscheduled): the **real BCI reader** — robustly
decoding continuous directional attention from EEG is an open research problem, so
the scripted trace stands in for a decoder we do not have; the **ceiling-mounted
headset actuator** — a safety-critical servo-cable rig where "at just the right
tension" is literally a force-safety constraint (hardware, out of software scope);
and the **Phase-2 integration** — this must implement the
[206](206-source-agnostic-input-abstraction-layer.md) source interface once that
exists, which it does not yet, so the decoder + tension model are proven standalone
and left unwired (see `src/experimental-bci/FINDINGS.md`).

## Intended Behavior (if/when pursued)

A **BCI aim source** that implements the exact same aim-source interface from 206,
so nothing downstream changes to accept it:

- **advance-one-tick** reads the brain-computer interface, decodes a coarse
  attention direction ("up-and-to-the-left" → attention drifting up and left), and
  maps it onto the canonical aim state's orientation. Discrete intents (fire /
  charge) would come from a chosen brain pattern or a physical fallback control.
- A **ceiling-mounted headset actuator**: the decoded attention direction drives a
  physical rig that moves a ceiling-hung headset "at just the right tension." That
  tension calibration is the poetic, hardware-real core of the dream — a servo/
  tension model matching head motion to attention.
- **activate / deactivate / descriptor** as any source: the descriptor would flag
  that it provides orientation but *not* real per-hand poses, so 205's idle/
  synthesized pose fills the hands (already handled by 206's design).

Because 206 made the interface source-agnostic, the entire rest of the game — the
renderer, spells, everything — accepts this source with zero changes. That is the
proof that the abstraction layer was worth building: a dream this far outside the
original two-mouse plan still plugs into the same socket.

## Suggested Implementation Steps (deferred — sketch only)

1. Pick a BCI input path (a consumer EEG headset SDK, or a raw signal source) and
   a decoder for coarse directional attention. This is research, not engineering.
2. Map decoded attention → the canonical aim orientation; decide the intent
   trigger (a brain pattern, or a physical button fallback — and if a fallback,
   announce it loudly per project fallback discipline).
3. Design the ceiling headset actuator + tension model as its own hardware
   sub-project; the software side only needs the decoded direction.
4. Implement it as a source registered into 206; validate with 206's fake-source
   test harness pattern (a scripted attention trace) before any real hardware.

## Structures & Functions By Role

- A **BCI aim source** implementing the 206 source interface.
- An **attention decoder** (raw BCI signal → coarse direction) — the research core.
- A **ceiling-headset actuator driver** (direction → physical tension) — the
  hardware core, out of software scope.

## Related Documents / Tools

- The seam this rides on: [206 — source-agnostic input abstraction layer](206-source-agnostic-input-abstraction-layer.md).
- Datapath: [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md)
  — listed under "where other phases plug in" as the deferred stretch source.
- Vision: [vision-overview.md](../docs/vision-overview.md) § Phase 2 stretch, and
  [notes/vision](../notes/vision) lines ~8-13.
- `src/experimental-bci/` — the software rehearsal (attention descriptor 006,
  decoder 007, ceiling-headset tension model 008, scripted-trace prover+demo 009,
  the run script) and each module's `.info.md`.
- `src/experimental-bci/FINDINGS.md` — what is proven in software, and the open
  EEG / actuator / force-safety unknowns.
