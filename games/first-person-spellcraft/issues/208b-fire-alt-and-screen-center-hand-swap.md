# 208b — Fire / alt action semantics & the screen-center grip↔trigger swap

> **Phase:** 2 — Dual-Mouse Aiming & Input — sub-issue of
> [208](208-dual-mouse-control-binding-and-locomotion-scheme.md).
> **Difficulty:** medium (the swap is a small state machine; the care is in making
> the role change legible so the player is never surprised which hand just fired)
> **Depends on / blockers:** [202](202-per-hand-state-and-hand-role-assignment.md)
> (the front/rear hand roles this rewrites), [204](204-dual-grip-aim-geometry.md)
> (the reticle whose screen-center crossing triggers the swap, and the
> front-vs-rear grip the roles feed), [206](206-source-agnostic-input-abstraction-layer.md)
> (the discrete-intent set these actions raise).
> **Blocks:** Phase 3's fire/charge consumption
> ([304b](304b-initial-casting-method-set.md)); the 208 umbrella's completion.

## Current Behavior

None of this exists yet — greenfield. Aim geometry (204) assigns a fixed front and
rear grip from the static hand roles (202), and 206 lists fire/charge/release/alt
as discrete intents with nothing raising them from the mice. Nothing decides which
hand's click *fires* versus *braces*, and the roles never change during play.

## Intended Behavior

The **action-and-role binding**: the half of the dual-mouse control map that turns
clicks into fire/alt intents and dynamically re-assigns which hand is the trigger
hand as the wand sweeps across the screen. Preserved verbatim from
[notes/vision-control-scheme](../notes/vision-control-scheme):

> the aiming reticle could be swapped from left hand on grip right hand on trigger
> to left hand on trigger right hand on grip when the reticle passes over the
> screen's center.

> ... if the left hand is on the trigger, then clicking with the left mouse will
> fire the weapon. the right trigger would do something else (right-mouse click)
> like flashlight or something like rocket launcher launched from the jetpack and
> aimed at the current position of your reticle.

Two coupled mechanics:

- **The screen-center grip↔trigger swap.** The two hands each hold a role — one on
  the **grip**, one on the **trigger**. When the reticle crosses the screen's
  vertical centre, the roles **swap**: the hand that was on the grip is now on the
  trigger and vice versa. This keeps the trigger hand on the natural side of the
  aim as the wand sweeps left-to-right, so firing never feels cross-armed. It is a
  small edge-triggered state flip (fire on the *crossing*, with a hysteresis band
  around centre so a reticle hovering on the line does not chatter the roles).
  Note this is distinct from 202's manual **swap-hands** (a persisted left/right
  rebinding for handedness); *this* swap is transient, automatic, and driven by
  aim — it changes *trigger-vs-grip*, not *left-vs-right device*.

- **Fire vs alt, by which hand holds the trigger.** The **trigger hand's** primary
  click raises the **fire** intent ("clicking with the left mouse will fire the
  weapon" when the left hand is the trigger hand). The **other** hand's click (the
  vision's "right trigger") raises the **alt** intent — the vision's examples are a
  **flashlight** or a **rocket launcher launched from the jetpack and aimed at the
  current position of your reticle**. Because the trigger role moves with the swap
  above, *which physical mouse fires* changes as the reticle crosses centre — the
  binding reads the current role, never a fixed device.

Both mechanics emit **discrete intents on the [206](206-source-agnostic-input-abstraction-layer.md)
aim state** — fire, alt, and any new action signals (flashlight, jetpack-rocket)
the scheme needs, extending 206's set — so a spell (Phase 3) or an effect reads a
normalized "fire" / "alt" without knowing which mouse or which hand produced it.
The jetpack-rocket's *aim* is the same reticle everything else uses ("aimed at the
current position of your reticle") — aim once, aim everywhere.

## Suggested Implementation Steps

1. Define the **role state** for the trigger↔grip assignment (which hand is on the
   trigger now), seeded from 202's starting roles, and the **swap event** that
   flips it.
2. Implement the **screen-center crossing detector** off 204's reticle: an
   edge-trigger on crossing the vertical centre, with a tunable hysteresis band so
   a reticle resting near centre does not oscillate. Record the band width in
   [docs/balance-updates.md](../docs/balance-updates.md).
3. On swap, rewrite the trigger/grip role and let 204's front/rear grip follow, so
   the barrel line and hand animation (205) stay consistent with who now holds
   what. Comment the boundary so a future editor does not confuse this transient
   swap with 202's persisted device swap.
4. Bind **fire** to the current trigger hand's primary click and **alt** to the
   other hand's click; raise them as discrete intents on the 206 aim state. Extend
   the intent set with the vision's flashlight and jetpack-rocket actions as
   distinct signals, each documented in 206's descriptor.
5. Make the role change **legible**: surface which hand is currently the trigger
   (a HUD cue via the pose channel / source descriptor), so the player is never
   surprised which hand just fired — an honest signal, not a hidden flip.
6. Tests (pure over synthetic aim + hand states): a reticle crossing centre flips
   the trigger role exactly once; a reticle jittering on the centre line inside the
   hysteresis band does *not* flip; the trigger hand's click raises fire and the
   off hand's click raises alt; after a swap, the *other* mouse now raises fire.

## Structures & Functions By Role

- A **trigger/grip role state** (which hand is the trigger) + a **swap** operation,
  seeded from 202's roles.
- A **screen-center crossing detector** with hysteresis, reading 204's reticle.
- An **action binding**: current trigger hand's click → fire intent; off hand's
  click → alt intent (flashlight / jetpack-rocket), raised on 206's aim state.

## Design Notes To Record As Comments

- Two different "swaps" live in this phase — keep them straight: 202's swap-hands
  is a *persisted left/right device* rebinding for a left-handed player; 208b's
  swap is a *transient trigger/grip* flip driven by the reticle crossing centre.
  Confusing them would either freeze the aim-driven swap or corrupt the persisted
  handedness. Comment both at the boundary.
- Why the alt actions (flashlight, jetpack-rocket) are intents, not hardcoded
  effects: keeping them as normalized signals on the aim state lets the gamepad
  (Phase 9) and an AI raise the same actions, and lets Phase 3 decide what "alt"
  *does* without this binding importing spell logic.

## Related Documents / Tools

- [notes/vision-control-scheme](../notes/vision-control-scheme) — the verbatim
  center-swap and fire/alt bindings.
- Datapath: [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md)
  — the control-binding stage; the discrete-intent set in stage [5].
- [204](204-dual-grip-aim-geometry.md) (reticle + front/rear grips),
  [202](202-per-hand-state-and-hand-role-assignment.md) (roles),
  [206](206-source-agnostic-input-abstraction-layer.md) (discrete intents).
- Parent: [208](208-dual-mouse-control-binding-and-locomotion-scheme.md). Sibling:
  [208a](208a-locomotion-and-body-control-from-two-mice.md).
