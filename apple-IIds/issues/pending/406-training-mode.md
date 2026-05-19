---
name: training mode
phase: 4
status: pending
blockedBy: [402]
---

# 406 — training mode

A settings option that keeps the radial overlay visible at all times
on the inactive screen, even when the left stick is in dead zone.
Helps learners build muscle memory.

## current behavior

The overlay appears only when the left stick is tilted (issue 402).
A new user has to explore by trial and error.

## intended behavior

- A boolean setting `training_mode` in the broker's config.
- When `true`: the overlay is always drawn on the inactive screen.
  Layer is the default (no modifiers) unless modifiers are held, in
  which case the layer shifts as it would in non-training mode.
- When `false` (default): the overlay only appears while the left
  stick is tilted.
- The setting is exposed through the phase 5 settings UI (issue 503)
  but can be toggled earlier via a config file at
  `~/.apple-IIds/config.lua`.
- Training mode does NOT change commit behavior. Characters still
  commit on right-stick release or stylus tap; the overlay being
  always-visible is purely cosmetic / pedagogical.

## suggested implementation steps

1. Add `training_mode` to the broker's config.
2. Extend issue 402's overlay renderer: if training mode is on, do
   not gate the overlay on left-stick dead-zone state — draw it
   always.
3. Provide a toggle. For phase 4: a config-file boolean. Phase 5's
   settings UI gives this a proper toggle.
4. Test: turn on training mode, observe the overlay is always on
   the inactive screen. Switch focus, observe the overlay flips to
   the newly-inactive screen.

## related documents

- `docs/003-input-system.md` — accessibility / training mode
- `issues/402-radial-overlay-renderer.md` — the renderer this extends
- `issues/503-settings-ui.md` — surfaces the toggle properly

## notes

- Worth keeping the always-on overlay slightly dimmer than the
  active-on-tilt version, so a trained user doesn't find it
  distracting while typing. Maybe 30% opacity baseline, jumping to
  full opacity on left-stick tilt.
