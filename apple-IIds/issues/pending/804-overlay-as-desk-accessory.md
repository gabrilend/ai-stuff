---
name: inactive-screen overlay as GS/OS desk accessory
phase: 8
status: pending
blockedBy: [402, 701]
---

# 804 — inactive-screen overlay as GS/OS desk accessory

The radial-keyboard overlay (issue 402) is moved from "broker draws
on the panel" to "GS/OS desk accessory drawing through QuickDraw."
This is the deepest visual-integration step: the overlay becomes a
native IIds program.

## current behavior

The overlay is drawn by the broker as a compositor layer on top of
the panel framebuffer. It doesn't use QuickDraw; it doesn't appear
in the IIds Window Manager's window list; the IIds doesn't know it
exists.

## intended behavior

- The overlay is implemented as a **desk accessory** (the GS/OS
  small-app convention for utilities) running in the inactive
  emulator's GS/OS.
- The DA receives input state (left-stick wedge, modifier state,
  preview-highlight cell) from the broker via a peripheral on the
  issue-701 infrastructure.
- The DA draws using ordinary QuickDraw, in a window that sits on
  top of normal windows. The aesthetic matches GS/OS's native
  look-and-feel.
- When the user switches focus, the overlay DA moves to the
  newly-inactive screen. The broker manages this by activating
  the DA on one instance and deactivating it on the other.
- The broker is no longer drawing on the panel directly for the
  overlay. (It still draws the status strip; that may also become
  a DA in a follow-up.)

## suggested implementation steps

1. Wait for issue 701 (peripheral infra).
2. Write the desk accessory in 65C816 assembly. It reads from a
   broker peripheral (`broker.overlay-state`) and renders the
   radial menu via QuickDraw.
3. Implement the broker side of the peripheral: state updates
   pushed via `device_event` to the inactive instance's DA.
4. Implement the focus-swap logic: when focus changes, deactivate
   on instance A and activate on instance B (or vice versa).
5. Test: visual fidelity with the prior broker-drawn version,
   responsiveness, focus-swap correctness.

## related documents

- `issues/402-radial-overlay-renderer.md` — the predecessor
- `issues/701-broker-virtual-peripheral-infra.md` — the channel
- `docs/003-input-system.md` — the overlay rule

## known design questions

- DA approach vs full application: a DA is the right shape — it's
  always available, doesn't show up in the application list, lives
  in the Apple menu. The cost is the DA mechanism is older and
  less powerful than full apps; check that QuickDraw from a DA
  context can do what we need (translucent windows, etc.).
- Performance: drawing through QuickDraw is slower than direct
  panel access. Should be fine for an overlay at 60 FPS but
  measure to confirm. If slow, native QuickDraw (issue 604) will
  fix it.

## notes

- This is one of the "optional polish" issues. The staging-ground
  overlay works fine; this issue makes it feel like part of the
  IIds rather than an external compositor. Worth it for the
  aesthetic cohesion but not load-bearing.
