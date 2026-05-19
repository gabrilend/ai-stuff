---
name: character emission via ADB
phase: 4
status: pending
blockedBy: [401, 402, 403]
---

# 404 — character emission via ADB

When the radial keyboard commits a character (either by right-stick
wedge entry or stylus tap), the broker injects it into the active
emulator's ADB keyboard event queue. To the IIds, it looks like an
ordinary key press.

## current behavior

Characters are visually selected via the overlay (issue 402) but
never actually emitted. The keyboard is a UI without a connected
output.

## intended behavior

- On a commit gesture, the broker:
  1. Looks up the character for the (left-wedge, right-wedge) or
     (left-wedge, stylus-tap-cell) pair.
  2. Determines the target emulator from `last_input.screen` (issue
     403).
  3. Constructs an ADB keyboard event: KeyDown with the appropriate
     Apple keycode, immediately followed by KeyUp.
  4. Inserts the event into the target emulator's ADB controller's
     event queue.
- The emulator's ADB driver hands the event to GS/OS as it would for
  a real keyboard press; GS/OS routes it to the focused window.
- The broker provides a lookup table from (wedge, sub-wedge) to ASCII
  character. The default mapping is the starting layout in
  `docs/003-input-system.md`. The lookup table is configurable.
- Modifiers (issue 405) wrap the KeyDown / KeyUp pair: if shift is
  held, the emitted event includes the shift modifier flag.

## suggested implementation steps

1. Build the wedge → character lookup table as a Lua module
   `src/broker/radial-layout.lua`. Export `lookup(left_wedge,
   right_wedge, modifiers) → ascii_or_special_key`.
2. Identify GSplus's ADB event injection path. It already has one
   for SDL keyboard input; the patch is to expose it as a Lua-callable
   function (or via a SmartPort-like channel).
3. Implement the commit handler: on a commit gesture (issue 401's
   stick state transition, or issue 409's stylus tap), look up the
   character, look up the target instance, inject.
4. Test by emitting a single character into a TextEdit window: see
   it appear at the cursor.
5. Test with the modifier flag (manual test, with L1 held; full
   modifier support is issue 405).

## related documents

- `docs/003-input-system.md` — what the emulator sees
- `issues/401-stick-quantization.md`,
  `issues/402-radial-overlay-renderer.md`,
  `issues/403-last-input-target.md` — the prerequisites
- `issues/405-modifier-keys.md` — wraps this for shifted characters
- `issues/702-broker-input-device.md` — the future path (post-phase 8
  this issue's ADB-emulation approach is replaced)

## known design questions

- Commit-on-release of the right stick, or commit-on-wedge-entry?
  Feel-test in phase 4 (issue 407). Default: commit-on-release
  (more deliberate, fewer mis-emissions).
- What about characters that ADB doesn't have a keycode for (e.g.,
  weird Unicode)? The IIds character set is Apple-extended ASCII;
  if the radial layout includes characters outside that set, they
  need to be emitted as multi-byte sequences via the Toolbox's
  high-level text input rather than via ADB. Out of scope for
  phase 4; phase 8's Broker Input device handles this cleanly.
