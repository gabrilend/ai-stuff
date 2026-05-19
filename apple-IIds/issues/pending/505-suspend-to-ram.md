---
name: suspend to RAM
phase: 5
status: pending
blockedBy: [201, 501]
---

# 505 — suspend to RAM

The Hall-effect sleep switch pauses both emulators when the device
"closes" (or sleeps from inactivity). RAM state is preserved; on
wake, both emulators resume from where they left off. **Nothing is
written to the SD card for sleep state.**

## current behavior

When the Hall sleep switch triggers, the broker has no response. The
device may just keep running the emulators, draining battery; or the
Linux kernel's default sleep handling may activate without the
broker knowing.

## intended behavior

- The broker listens for the Hall switch via the appropriate input
  device. On "switch closed" (lid shut):
  1. Both emulators are paused (CPU emulation halted; their state
     remains in RAM, untouched).
  2. The broker enters a low-power loop, waking only on the next
     Hall-switch event.
  3. Panel framebuffers and audio outputs go to low-power state
     (panels off, audio muted).
  4. CPU/GPU governors are pushed to a deep idle.
- On "switch opened" (lid open / wake):
  1. Panels come back on.
  2. Audio resumes.
  3. Both emulators resume from their paused state — same RAM,
     same registers, no boot, no reload.
- No state is serialized to SD card. The only persistent state
  across sleep is what was already on disk before sleep (user
  documents, etc.).
- If the battery dies during sleep, the device cold-boots on next
  power-on. This is expected and accepted; we don't try to recover.

## suggested implementation steps

1. Identify the Hall-effect sleep switch's input device. Confirm
   during issue 101's hardware survey.
2. Add a broker watcher that listens for switch events.
3. On switch-closed, pause both emulator processes — GSplus
   probably already has a "pause" command; if not, send SIGSTOP.
4. Implement the panel-off and audio-mute hooks.
5. Implement CPU governor adjustments (likely via
   `/sys/devices/system/cpu/...`).
6. On switch-opened, reverse all of the above.
7. Test: open a document, type a line, close the lid, wait, open
   the lid, see the document right where you left it.

## related documents

- `docs/001-architecture-overview.md` — operational constraints,
  suspend to RAM
- `docs/002-hardware-target.md` — Hall switch
- `issues/506-sd-write-minimization.md` — adjacent concern

## known design questions

- How long can the device stay in sleep before the battery dies?
  4000 mAh battery, ~6 h runtime when active. Sleep should be at
  least 10x less power draw, so ~60 hours of sleep ideally.
  Measure during phase 5.
- What if the broker crashes during sleep? Unlikely (nothing is
  running), but if it happens, the device cold-boots on next wake.
  Same as battery-dies path.

## notes

- The "no SD writes for sleep" rule is what makes this issue
  pleasant. If we wrote state to SD on every sleep, we'd be
  wearing the card constantly. Trusting RAM is fine; RAM survives
  as long as power survives.
