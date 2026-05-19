---
name: Broker Input device (second OS-level mod)
phase: 7
status: pending
blockedBy: [106, 701]
---

# 702 — Broker Input device

The **second OS-level modification** in the project, after the
About-string proof from issue 106. Establishes the cross-surface
coordinated-patch pipeline as production-ready, and creates the
single seam through which every future "modern hardware → GS/OS"
input pathway flows.

## current behavior

GS/OS reads input only from emulated ADB hardware. The radial
keyboard (phase 4), touch (issue 104), and any future input source
(gyro, voice, whatever) all have to disguise themselves as ADB events
that the broker injects into the emulator's ADB controller. Works,
but it's a fiction — and a tax. Every new input source pays it.

## intended behavior

A first-class input device that GS/OS knows about by name. The broker
writes events into it from outside; GS/OS reads events from it
through a normal Device Manager driver and posts them into the Event
Manager queue. No ADB layer involved.

Three surfaces coordinate:

- **GSplus (patch `100-broker-input.gsplus.patch`):** a new virtual
  peripheral exposed at a defined memory-mapped I/O address. The
  peripheral is essentially a ring buffer: the broker (running outside
  GSplus) writes input event records into the buffer; the emulated
  IIgs reads them via MMIO.
- **GS/OS (patch `100-broker-input.gsos.s.patch`):** a new Device
  Manager driver that knows how to talk to the new peripheral, plus a
  small Event Manager extension that drains the driver's queue each
  event-loop tick and posts the events as if they had originated in
  ADB.
- **Broker (`src/broker/100-broker-input.lua`):** a single function
  `broker.post_input(screen, event)` that writes into the right
  peripheral. All future input sources (touch, radial keyboard, gyro)
  call this.

Once landed, the test that proves it works is:

```
poke a synthetic 'X' keystroke into the broker
→ X appears in a TextEdit window on the focused screen
```

End-to-end, with no emulated ADB involved.

## why this is the right second mod

- **Coordinated across two upstream surfaces.** Proves the
  cross-surface patching machinery from `docs/005-patch-conventions.md`
  works in production. The About-string mod (issue 106) only
  exercises one surface.
- **The single seam for everything else.** Every later issue that
  liberates a new input source (touch in phase 8, radial keyboard in
  phase 8, gyro in phase 8, future inputs we haven't imagined) reuses
  this seam. We pay the cost once.
- **Testable end-to-end with a one-line script.** No subjective UX
  feel, no hardware-in-hand dependency. Either the keystroke appears
  or it doesn't.
- **Doesn't touch the ROM.** The Toolbox stays untouched. Everything
  lives in surfaces we own (GSplus C source, GS/OS released source).
- **Modest in size.** A few hundred lines on each side.

## suggested implementation steps

1. Pick the MMIO address. GSplus's virtual address space has unused
   regions; choose one that doesn't collide with anything GS/OS
   expects. Document the choice.
2. Write the GSplus side first. The peripheral is a tiny module —
   a ring buffer, a write port (broker → buffer), a read port (CPU
   → buffer), an interrupt line that fires when the buffer transitions
   from empty to non-empty. Test it from a debug menu: type into
   GSplus's host SDL window, see bytes appear at the MMIO address
   from the IIgs's perspective (verified via an inline 65C816
   monitor or a print in the IIgs's startup code).
3. Write the GS/OS side. The Device Manager driver follows the
   standard GS/OS driver template (DOpenDriver, DReadDriver,
   DControlDriver, etc.). The Event Manager extension polls the
   driver once per pass through `GetNextEvent`.
4. Write the broker side. `broker.post_input(screen, event)` writes
   to the correct emulator's MMIO peripheral. Event records are
   small (a few bytes — type, data1, data2, modifiers, timestamp).
5. The integration test: `broker.post_input("A", {type="key", key="X"})`
   from a Lua REPL on the host, observe X in the focused screen's
   TextEdit.
6. Once green, document the event-record format in `docs/` and
   reference it from phase 8 issues (touch, radial keyboard, gyro)
   so they can all use the same channel.

## what this issue does *not* do yet

- Doesn't wire any actual modern hardware (touch, sticks, gyro) to
  the broker. That's phase 8.
- Doesn't bypass ADB entirely — ADB still exists and still works for
  software that polls it directly.
- Doesn't introduce threading. The broker is still single-threaded;
  the GS/OS side runs in the cooperative GS/OS event loop. Threading
  comes in phase 9.

## related documents

- `docs/001-architecture-overview.md` — modification surfaces
- `docs/005-patch-conventions.md` — apply/unapply discipline
- `issues/106-gs-os-source-toolchain.md` — the prerequisite
- `docs/004-roadmap.md` phase 7 — the broader context

## related tools

- GSplus source (libs/gsplus/)
- GS/OS source (libs/gsos-src/)
- Merlin32 or ca65 for assembling the GS/OS-side changes

## license note

The new files we author (the broker module, the GS/OS-side .s files
that aren't direct edits to Apple's release) are ours and ship as
permissive (BSD/MIT). The patches against GSplus and GS/OS source
inherit those upstreams' licenses; both are compatible with our
third-party-deployment posture (see `docs/001-architecture-overview.md`
operational constraints).
