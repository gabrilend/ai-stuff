# 902 — Handheld input fallback: gamepad as a Phase-2 input source

> **Phase:** 9 — Platform & Packaging
> **Role in phase:** the load-bearing cross-phase seam. On the handheld there are
> no mice, so the signature two-mouse boomstick aim must **degrade gracefully** to
> a gamepad. This issue adds the gamepad as *another source behind Phase 2's input
> abstraction* — it does **not** redesign that abstraction.
> **Blocked by (within phase):** 901 (the profile tells us the pad's stick/button
> inventory, which sets how far the aim can degrade).
> **Depends on (across phases):** Phase 2 (the input abstraction layer this plugs
> into). This issue **describes** that interface; it must not rewrite it.

## Current Behavior

None of this exists yet. Phase 2's input abstraction turns raw devices into an
aim/hand intent, and today its only real source is the two-mouse boomstick (plus
the documented-only BCI stretch). There is no gamepad source, so on a device with
no mice the game would have no way to aim at all.

## Intended Behavior

The handheld's **gamepad becomes a source behind Phase 2's existing input layer**,
filling the *same* aim/hand intent the two-mouse boomstick fills, so that every
upstream system (movement, spell aiming, NCP control) keeps reading "aim intent"
without ever learning which physical device produced it. The signature dual-mouse
aim degrades **gracefully**, along a stated ladder from richest to leanest:

- **Two mice** — the full boomstick, two hands driven independently. (desktop; not
  this issue's concern, but the top of the ladder it degrades *from*.)
- **Twin stick** — one stick per hand, on pads with two sticks. The closest
  handheld analogue to two mice: left stick ≈ left hand, right stick ≈ right hand.
- **Single stick + modifier** — where only one usable stick exists, the stick aims
  one hand and a shoulder button switches which hand it drives (or binds the
  off-hand to a coarser assist). The two hands are time-shared rather than
  simultaneous.

Which rung the handheld lands on is decided by the **stick/button inventory in the
hardware profile (issue 901)** — not guessed. If the profile shows two sticks, the
twin-stick rung binds; if one, the single-stick rung binds.

The join is a **source registration**, not a fork of gameplay code: the gamepad
source presents itself to Phase 2's layer, declares which degradation rung it is
on, and from then on is indistinguishable to everything upstream. The "feel" gap
between a wave-two-mice boomstick and a nudge-a-stick aim is expected and
acknowledged; the goal is *graceful*, not *identical*.

A note kept honest per the no-silent-fallback rule: dropping from two hands to a
time-shared single stick is a **real capability loss**, and it should be surfaced
(e.g. a one-line "single-stick mode" acknowledgement), not hidden.

## Suggested Implementation Steps

1. Read Phase 2's input abstraction contract first — the exact shape of the aim/
   hand intent it exposes and how a source registers behind it. Do not change it.
2. Define the **gamepad input-source binding**: the mapping from gamepad sticks/
   buttons to that aim/hand intent, carrying a field for **which degradation rung**
   it represents.
3. Implement rung selection: read the stick/button inventory from the hardware
   profile (901) and pick twin-stick vs single-stick+modifier accordingly.
4. Implement the **twin-stick** binding (stick-per-hand).
5. Implement the **single-stick + modifier** binding (shoulder button switches the
   driven hand; document, in a comment, what each branch of that switch does).
6. Register the gamepad source behind Phase 2's layer so upstream code is unchanged.
7. Surface the active rung to the player when it is a degraded one (an honest
   acknowledgement, not a hidden shrink).
8. Add a test that feeds synthetic gamepad input through Phase 2's layer and checks
   the produced aim intent matches on both rungs — one small validating test per
   rung.

## Stats / Meta

- **Kind:** cross-phase seam (Phase 9 → Phase 2).
- **Redesign of Phase 2?** No — additive source only.
- **Degradation rungs:** twin-stick, single-stick+modifier (below the desktop
  two-mouse top rung).

## Related Documents / Tools

- [datapath-platform-packaging.md](../docs/datapath-platform-packaging.md) — the
  "Input seam" section: the ladder and the rule that upstream never learns the rung.
- [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md) — Phase 2's
  own datapath; the interface this issue plugs into and must not redesign.
- Issue **901** — supplies the pad's stick/button inventory that picks the rung.
