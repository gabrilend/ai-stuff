---
name: wedge count and layout calibration
phase: 4
status: pending
blockedBy: [401, 402, 404, 405]
---

# 407 — wedge count and layout calibration

Hardware-in-hand testing decides the final wedge counts (4 or 8 per
stick) and the character assignments per cell. The defaults from
`docs/003-input-system.md` are starting points; this issue produces
the locked-in version.

## current behavior

The defaults assume 8 wedges per stick and the layout from
`docs/003-input-system.md`. Without device-in-hand testing, these
are guesses.

## intended behavior

- A calibration session on real hardware produces:
  - The chosen wedge count per stick (4 or 8, possibly mixed).
  - The chosen character per (left-wedge, right-wedge) cell, for
    each of the base, L3, and R3 layers.
  - The chosen commit timing (commit-on-release vs
    commit-on-wedge-entry).
  - The chosen hysteresis and dead-zone settings.
- The results are written into `src/broker/radial-layout.lua` as
  the new defaults.
- A diagnostic mode displays the current layout overlay on demand
  (regardless of training_mode setting), with the user able to tap
  cells to remap them.

## suggested implementation steps

1. Run the device through extended typing sessions (a paragraph, a
   sentence, individual letters from each part of the layout).
2. For each cell that proved unreliable (mis-fires, repeated
   mis-targets), record the issue: hard-to-aim wedge boundary,
   ambiguity between adjacent cells, etc.
3. Adjust: drop a problematic 8-wedge to 4-wedges; move characters
   to easier cells; redistribute the L3/R3 layer if necessary.
4. Validate: a typing-test with the adjusted layout; aim for a
   target words-per-minute and accuracy.
5. Commit the final layout to `src/broker/radial-layout.lua` as a
   versioned default. Old layouts remain available via a config
   option for users who learned the old layout.

## related documents

- `docs/003-input-system.md` — starting layout and grid
- `issues/401-stick-quantization.md` — adjusts the hysteresis
- `issues/404-character-emission-adb.md` — the lookup table
- `issues/405-modifier-keys.md` — the L3/R3 layers being calibrated

## known design questions

- Should we support multiple layouts (e.g., QWERTY-feel vs
  frequency-optimized)? Defer to a follow-up; for phase 4 we ship
  one layout, period.
- Should the user be able to remap cells through a UI? Yes —
  diagnostic mode supports it. The phase 5 settings UI (issue 503)
  exposes the remapper to ordinary users.

## notes

- This issue can't be properly executed without the RG DS in hand
  for at least a full day of typing tests. Treat it as a hardware-
  testing milestone, not a code-only issue.
- Document the chosen layout with an SVG diagram in
  `docs/HTML/radial-layout.html` (phase 5 docs site).
