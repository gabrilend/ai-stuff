# 208 — Dual-mouse control binding & the locomotion scheme (umbrella)

> **Phase:** 2 — Dual-Mouse Aiming & Input
> **Difficulty:** medium-hard (little of it is hard code; the work is choosing a
> control map that *feels* right and keeping every binding on the source-agnostic
> side of the wall so it degrades to a gamepad later without a rewrite)
> **Depends on / blockers:** [202](202-per-hand-state-and-hand-role-assignment.md)
> (hand roles — which hand is which), [204](204-dual-grip-aim-geometry.md) (the
> reticle/aim and the front/rear grips this map switches between),
> [201b](201b-per-device-evdev-read-loop.md) (button + wheel edges),
> [206](206-source-agnostic-input-abstraction-layer.md) (the aim state and source
> registry these intents publish through), and Phase 1's **IntentFrame** seam
> ([datapath-engine-foundation.md](../docs/datapath-engine-foundation.md)) — the
> movement channel this fills.
> **Blocks:** it *completes* Phase 1's deferred movement-intent translator (issue
> [107](107-engine-seams-and-phase-1-capstone-demo.md) demonstrates that seam with
> a throwaway scripted translator; this is its real filling), feeds Phase 3's
> fire/charge intents ([304b](304b-initial-casting-method-set.md)), and is the
> desktop rung the Phase 9 gamepad fallback ([902](902-handheld-input-fallback-gamepad-as-phase-2-source.md))
> degrades *from*.
> **Sub-issues:** [208a](208a-locomotion-and-body-control-from-two-mice.md) (body &
> locomotion), [208b](208b-fire-alt-and-screen-center-hand-swap.md) (action &
> hand-role swap).

## Why this issue exists (the gap it closes)

Phase 1's loop fills an **IntentFrame** — move-forward, strafe, turn, jump — and
says of it: "stub translator now; Phase 2 replaces it." Phase 2's issues 201–206
then build the *aim* half of the boomstick (where it points, and the spell intents
fire/charge/release/alt) and the source-agnostic seam they publish through — but
**no issue ever builds the translator that turns the two mice into movement**. The
whole of [notes/vision-control-scheme](../notes/vision-control-scheme) is that
missing translator: the map from two mice (buttons, wheels, reticle position) to
"the body walks / turns / thrusts / rises / fires." This umbrella and its two
sub-issues are that map, so the promise Phase 1 made to Phase 2 is finally kept.

## Current Behavior

None of this exists yet — greenfield. The aim pipeline (201–206) can say *where*
the boomstick points and whether a spell fire/charge intent is raised, but nothing
says how the two mice **move the body**: no forward, no turn, no strafe, no jump,
no jetpack thrust or height. On the desktop, a player with two grabbed mice could
aim a wand at the world and never take a step. Phase 1's movement systems read an
IntentFrame that, without this issue, only a test stub ever fills.

## Intended Behavior

A **dual-mouse control binding**: the desktop translator that reads the two hands'
button/wheel/position state each tick and fills **two** downstream channels —

1. **Phase 1's movement IntentFrame** — forward, strafe, turn, jump/height — so
   the existing movers (105/106) walk the body without ever learning a mouse
   exists. This is the channel Phase 1 stubbed and deferred here.
2. **Phase 2's discrete-intent set** (on the [206](206-source-agnostic-input-abstraction-layer.md)
   aim state) — fire, alt, and any new action signals the scheme needs — so a
   spell (Phase 3) or the HUD reads a normalized "fire" without knowing a left
   mouse button raised it.

The vision fixes the scheme's flavour — it is not a plain WASD analogue, it is a
**"helicopter jetpack"** wand-pilot rig — and gives specific, sacrosanct bindings
(preserved verbatim in the sub-issues). Two properties bind the whole cluster:

- **Everything is a binding into an intent, never a device read by a mover.** The
  binding lives on the *source* side of the [206](206-source-agnostic-input-abstraction-layer.md)
  wall. Movement code and spell code read intents; only this binding reads the
  mice. That is exactly what lets the Phase 9 gamepad ([902](902-handheld-input-fallback-gamepad-as-phase-2-source.md))
  produce the same movement + action intents from sticks and buttons with no
  change upstream — "aim once, aim everywhere," now extended to *move* once, move
  everywhere.
- **The vision names design *alternatives*; they are documented modes, not a
  half-wired branch.** vision-control-scheme offers two ways to turn (by click vs
  by reticle screen-position) and two ways to sidestep (mouse-strafe vs a held
  "hover mode"). Per the project rule that added modes must both be proven working
  before either is called complete, each alternative is a selectable mode with its
  own test; one ships as the primary and the other is a live, tested option — never
  a commented-out guess.

**Deferred within this cluster (party-linked, noted not built):** the vision's
middle-mouse **ally signals** — *"make a signal to your allies 'look over here' or
'go over there' or 'control the air'"* — presume allies, and multiple adventurers
are a sequel feature ("save parties for the sequel"). The signal *binding* is
recorded here as a reserved middle-mouse intent so the map has a place for it, but
the signalling behaviour is deferred with the party system, the same way
[207](207-stretch-bci-ceiling-headset-source.md) reserves the BCI seam without
building it.

## Suggested Implementation Steps

1. Build [208a](208a-locomotion-and-body-control-from-two-mice.md) first — the
   locomotion/body bindings that fill Phase 1's movement IntentFrame — since it is
   what makes the desktop playable and what the Phase 1 movers already expect.
2. Build [208b](208b-fire-alt-and-screen-center-hand-swap.md) — the action
   (fire/alt) bindings and the screen-center grip↔trigger hand-role swap, which
   feeds the discrete intents and rewrites which hand is front/rear.
3. Register the whole binding as part of the **dual-mouse source** (206): its
   per-tick advance now packs movement intents + discrete intents alongside the
   aim orientation and pose channel it already produces. One source, one advance,
   all channels.
4. Reserve the middle-mouse **ally-signal** intent slot (deferred behaviour) and
   comment it as party-linked, so the map is complete and the sequel has a socket.
5. Prove the cluster by replacing issue 107's throwaway scripted-intent translator
   with this real one: the same demo world now walks, turns, thrusts, and fires
   from two mice. Record the tuned control constants (turn rate, thrust/height
   response, dead-zones for the turn-by-position band) in
   [docs/balance-updates.md](../docs/balance-updates.md).

## Structures & Functions By Role

- A **control-binding** unit that, per tick, reads both hand states (202) + the
  aim/reticle (204) and emits a *movement-intent fill* (for Phase 1) and a
  *discrete-intent fill* (for 206's aim state).
- A **control-mode selector** (dispatch over mode key, per project convention) for
  the turn and sidestep alternatives — never an if/else over "which scheme."
- The two sub-issue pieces: locomotion (208a), action + hand-swap (208b).
- A reserved **ally-signal intent** (deferred), keyed to middle mouse.

## Design Notes To Record As Comments

- Why this fills *two* channels: movement intents belong to Phase 1's IntentFrame
  (the mover reads them), spell/action intents belong to Phase 2's aim state (the
  spell reads them). The binding is the one place both are produced from the mice;
  keeping them as separate output channels is what lets movement and spells evolve
  independently of the control map.
- Why the alternatives are modes, not branches: the vision proposes competing feel
  experiments (turn-by-click vs turn-by-position, strafe vs hover). Wiring one and
  deleting the other would lose a documented intent; wiring both behind a selector
  keeps the experiment alive and testable, per house rule.

## Related Documents / Tools

- [notes/vision-control-scheme](../notes/vision-control-scheme) — the sacrosanct
  source of every binding in this cluster.
- Datapath: [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md)
  — the "control binding" stage (two mice → body & action intents).
- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — Phase 1's
  IntentFrame this binding fills; issue [107](107-engine-seams-and-phase-1-capstone-demo.md)'s
  translator seam.
- Sub-issues: [208a](208a-locomotion-and-body-control-from-two-mice.md),
  [208b](208b-fire-alt-and-screen-center-hand-swap.md). Degraded by:
  [902](902-handheld-input-fallback-gamepad-as-phase-2-source.md).
