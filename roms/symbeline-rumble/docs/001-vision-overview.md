# Vision Overview

Source-of-truth: [`notes/vision`](../notes/vision). This document distills the
vision into design-facing terms and flags what remains open.

## What the game is

Symbeline Rumble is a vertically-oriented, 3D, tilt-shift-styled real-time
strategy skirmish, modeled on Warcraft Rumble. Its canonical hardware target is
the Nintendo DS (delivered as a `.nds` ROM), with a co-equal native Linux/ARM
build produced from the same source. The vertical form factor is load-bearing:
the play space is read as two stacked screens, not a single landscape view.

## What is decided

- **Map shape.** Two tiles wide by two tiles tall, but only one tile-pair is
  visible at a time. The L and R shoulder buttons page between the left and
  right halves of the world. Tapping the same shoulder again from the page it
  already shows opens a menu specific to that half.
- **No on-map HUD.** Gold appears as section-marks on a bar near owned
  infrastructure. Player notifications appear as speech bubbles. Everything
  else lives inside menus opened via L/R.
- **Pre-defined unit paths.** Units leave their spawn structure (barracks,
  guardhouse) and follow corralled paths through the terrain. The map's
  architecture *is* the strategy layer, in the WC3 tradition.
- **Combat happens on contact.** Units encountering enemies fight in place.
- **Gold has two sources.** Passive yield from gemstone mines, and active yield
  from treasure-chests that a unit must physically return for credit.
- **Total gold cap is owned-structures-dependent.** Capture more, cap more.
- **Deck cycles.** Units that are unplayable (dead, on cooldown, lost) are
  pulled from the deck until they are playable again.
- **Meta-progression between matches.** Units are adventurers with classes,
  levels, and equipment, mutating loadouts in the style of Fire Emblem.
  Behavior patterns are part of the loadout — how a unit acts on the map is
  specced ahead of time, not micro-managed.
- **Tilt-shift, applied as design rule.** Blurred regions of the frame contain
  scenery only, never units. Units always render in the sharp band.
- **Spell casting.** Cast via the L/R menu or by targeting a friendly unit. The
  Anbernic DS supports top-screen touch, but the original DS does not — for
  cross-target parity, top-screen targeting is treated as a possibly-absent
  capability rather than a baseline assumption.

## What is open

- Number of unit classes at first playable.
- Length of a single match (rough target: 5–10 min).
- Whether scenery-blur is real-time post-process or pre-baked into sprite
  layers — this is a tilt-shift divergence between targets, tracked in the
  divergence grid (`005-divergence-grid.md`).
- Whether maps loop, branch, or only proceed linearly via a campaign tree.
- The exact behavior-pattern vocabulary (e.g., "hold", "advance", "raid",
  "escort") and how patterns combine.
- Whether match seeds support replay — the fixed-point-only gameplay rule
  (`008-fixed-point-math.md`) preserves the option, but the format and tooling
  are not yet designed.

## What is explicitly out

- **Vertical menu chrome on the play surface.** No bars, no nameplates, no
  floating numbers. The map is the map.
- **Float math in gameplay code.** See `008-fixed-point-math.md`.
- **Detection-evasion of platform constraints.** If the DS cannot do
  real-time depth-blur, the DS gets a different tilt-shift solution and we
  log the divergence. We don't pretend.

## Why these constraints

The author's interest is in software design, not product. Constraints
(vertical screen, fixed gold sources, no on-map HUD, fixed-point math)
narrow the design space enough that decisions can be evaluated against
each other, rather than against an open product backlog.
