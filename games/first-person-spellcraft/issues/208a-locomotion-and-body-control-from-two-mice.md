# 208a — Locomotion & body control from the two mice

> **Phase:** 2 — Dual-Mouse Aiming & Input — sub-issue of
> [208](208-dual-mouse-control-binding-and-locomotion-scheme.md).
> **Difficulty:** medium (small math; the work is feel + keeping it intent-shaped)
> **Depends on / blockers:** [202](202-per-hand-state-and-hand-role-assignment.md)
> (which hand is which, and each hand's buttons/wheel),
> [204](204-dual-grip-aim-geometry.md) (the reticle screen-position the
> turn-by-position mode reads), Phase 1's movement + vertical systems
> ([105](105-player-movement-and-wall-collision.md),
> [106](106-platforming-gravity-jumping-vertical-collision.md)) which consume the
> IntentFrame this fills.
> **Blocks:** the desktop being walkable at all; the 208 umbrella's completion.

## Current Behavior

None of this exists yet — greenfield. Phase 1's movers read forward / strafe /
turn / jump from an IntentFrame that only a test stub fills. The two mice can aim
a wand but cannot take a step, turn the body, rise, or thrust.

## Intended Behavior

The **locomotion binding**: the half of the dual-mouse control map that fills
Phase 1's movement IntentFrame. The vision frames the body not as a walker but as
a **wand-pilot on a "helicopter jetpack"**, and gives specific bindings. Preserved
verbatim from [notes/vision-control-scheme](../notes/vision-control-scheme):

> right click uses the corresponding half of your lower body, left click does
> the same. ... if the user uses the right-click on the left or right mouse, the
> character would turn left or right correspondingly. if the user clicked BOTH
> right mouth [mouse] buttons at the same time, the character would move forward.
> scroll wheels control height inertia, left and right thruster implied.

and the two design alternatives the vision offers:

> alternatively, instead of flashlight the off-hand could enable "hover mode"
> while held which meant that left and right mouse would be strafe-es.

> alternatively, instead of turning with the mouse clicks, we could just turn
> according to the aiming of the mouse. between 0% and 24% of the screen would
> turn the camera left, 76% of the screen and 100% of the screen would turn right.

Concretely, the bindings that fill the movement IntentFrame:

- **Turn.** Two documented modes, selected by the 208 mode-selector (both built and
  tested per house rule; one ships primary):
  - **turn-by-click** — right-click on the left mouse turns left, right-click on
    the right mouse turns right (the "corresponding half of your lower body").
  - **turn-by-reticle-position** — the aim's horizontal screen fraction drives
    turn: in the outer-left band (roughly the vision's **0%–24%**) the camera turns
    left, in the outer-right band (**76%–100%**) it turns right, with a neutral
    dead band in the middle so aiming near centre does not spin the body. The
    exact band edges are tuned knobs, recorded in
    [docs/balance-updates.md](../docs/balance-updates.md), not hardcoded here.
- **Forward.** Both right-mouse buttons pressed together raises the forward-move
  intent — the "helicopter" nose-down surge.
- **Height / thrust.** The two scroll wheels drive **height inertia** (a vertical
  thrust intent that feeds Phase 1's vertical velocity — left wheel and right wheel
  read as the two thrusters, so asymmetric scrolling can bias the climb). Because
  Phase 1 owns gravity and vertical collision (106), this binding only raises a
  *thrust/height intent*; it never moves z itself.
- **Strafe / sidestep.** Two documented modes (both built + tested; one primary):
  - **mouse-strafe** — a left/right sidestep intent bound to the appropriate mouse
    motion/button.
  - **hover mode** — while the off-hand holds its hover control, left and right
    mouse become **strafes** (the vision's explicit alternative). Entering hover is
    a real capability change and is surfaced, not hidden (no silent mode flip).

All of the above emit **intents into Phase 1's IntentFrame** — forward, strafe,
turn, jump/height — and nothing reads a mover directly. Turn/forward/thrust
magnitudes are tuned constants in `docs/balance-updates.md`, since brisk-but-not-
twitchy piloting is a knob turned often (the same discipline issue 105 uses for
its move speeds).

## Suggested Implementation Steps

1. Define the **movement-intent fill** the binding produces each tick (forward,
   strafe, turn, thrust/height), matching the exact IntentFrame field set Phase 1
   (102/105/106) reads — confirm the field shapes with that seam, do not invent a
   parallel one.
2. Implement **turn-by-click** and **turn-by-reticle-position** as two modes behind
   the 208 mode-selector; give the position mode a tunable neutral dead band and
   read the horizontal reticle fraction from 204's aim result.
3. Implement **forward** (both right buttons), reading the per-hand button state
   from 202 (held vs edge).
4. Implement **height/thrust** from the two scroll wheels as a vertical thrust
   intent; comment that it feeds 106's vertical velocity and must never write z.
5. Implement **mouse-strafe** and **hover-mode strafe** as two modes; surface the
   active mode when hover is engaged.
6. Record all tuned constants (turn rate, band edges, thrust response, dead-zones)
   in `docs/balance-updates.md` with the reasoning, per the knob-tuning discipline.
7. Tests (pure over synthetic hand states — no hardware): both-right-buttons raises
   forward; a reticle fraction in the left band raises turn-left and one in the
   centre raises no turn; a scroll delta raises thrust; hover-mode flips left/right
   mouse to strafe. One small test per binding and per mode.

## Structures & Functions By Role

- A **locomotion binding** function: (hand states + aim result) → movement-intent
  fill.
- Two **turn-mode** functions (by-click, by-position) and two **sidestep-mode**
  functions (mouse-strafe, hover), each registered behind the 208 mode-selector.
- A **thrust/height** reader over the two scroll wheels.

## Design Notes To Record As Comments

- Why thrust raises an intent, not a z write: Phase 1 (106) owns gravity, the
  ground/ceiling clamp, and the on-ground flag. If this binding moved z directly it
  would fight the platformer. It raises a vertical *thrust* intent and lets 106
  integrate it — the same reason 105's movement reads intents, not devices.
- Why turn has two modes: the vision is unsure whether the body should turn from a
  discrete click or continuously from where the reticle sits on screen. Both are
  real feel experiments; keeping both behind a selector honours "added modes must
  both be proven working," and lets play-testing pick the primary without deleting
  the loser.

## Related Documents / Tools

- [notes/vision-control-scheme](../notes/vision-control-scheme) — the verbatim
  bindings and the two alternatives.
- Datapath: [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md)
  — the control-binding stage.
- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — the
  IntentFrame + Phase 1 movers this fills.
- Parent: [208](208-dual-mouse-control-binding-and-locomotion-scheme.md). Sibling:
  [208b](208b-fire-alt-and-screen-center-hand-swap.md).
