---
name: architecture overview
status: draft (planning phase, 2026-05-19)
---

# architecture overview

Three layers, bottom to top.

## layer 1 — the host (Anbernic RG DS)

The Anbernic RG DS handheld, running a Linux 64-bit userland (it ships
with both Android 14 and Linux as supported targets — we pick Linux).
Provides:

- two 640×480 IPS panels (top + bottom), both multi-touch with capacitive
  stylus support
- a Rockchip RK3568 SoC (quad-core ARM Cortex-A55 @ 2.0 GHz, ARM G52 GPU)
- 3 GB RAM, 32 GB internal storage, microSD up to 2 TB
- two analog sticks (clickable, so each is also a button), d-pad, four face
  buttons, two L buttons, two R buttons, two Start + two Select buttons
  (right-side and bottom-left pairs), volume up/down, power
- two USB-C ports (one labeled DC/USB, one labeled OTG), 3.5 mm headphone
  jack, stereo speakers
- six-axis gyroscope, vibration motor, Hall-effect sleep switch
- Bluetooth 4.2, WiFi 802.11ac (2.4/5 GHz)
- 4000 mAh battery, ~6 h runtime

This layer is **not ours to build**. It exists. We target it.

## layer 2 — the broker

A thin LuaJIT process that owns the device. It does five things:

1. **Spawns and supervises** two GSplus instances (one per screen).
2. **Owns the shared filesystem.** Both emulated IIgses see the same files.
   The broker resolves which emulator's writes win on conflict
   (last-writer-wins for now, provisional). Once we modify GS/OS, the
   shared filesystem stops being a fiction layered over virtual disk
   images and becomes a first-class GS/OS device driver.
3. **Owns the shared clipboard.** Copy on screen A, paste on screen B.
   Talks to each emulator's Scrap Manager through a stub we add to GS/OS.
4. **Routes input.** Touches on a screen go to that screen's emulator.
   Stylus input is treated the same as touch (the RG DS exposes both
   through the same digitizer). Stick input routes to whichever screen
   currently has keyboard focus. The radial-keyboard renderer is also
   broker-side (it draws onto the bottom panel as an overlay, not inside
   the emulated IIgs).
5. **Implements an IPC channel** between the two emulators so that
   custom-written applications can coordinate explicitly across screens.
   The channel is modeled on AppleTalk but rides on a Unix-domain socket
   underneath; both endpoints look like network sockets to GS/OS code.

The broker is single-threaded today and one cooperative scheduler tick per
frame is enough for everything it does. **Pending soramech**, the broker
will become multithreaded: each emulator and each native subsystem rewrite
will run on its own thread, with shared state mediated by the soramech
primitives.

## layer 3 — the emulated IIgses

Two GSplus instances. GSplus is a BSD-licensed open-source emulator
descended from KEGS (Kent's Emulated GS) — important to us because the
emulator itself is fully modifiable in tandem with the OS modifications.

Each emulator runs:

- a real IIgs boot ROM (loaded separately; not redistributable),
- a GS/OS boot disk image — initially a stock image, eventually replaced
  with a disk we built from Apple's publicly-released GS/OS source.

From the emulator's perspective, the broker appears as a virtual peripheral
— a strange disk drive that sometimes shares files with another drive, a
strange clipboard that sometimes contains data the user didn't type. Once
GS/OS is modified, the broker becomes a real first-class device that
GS/OS knows about by name.

### the future seam

Each Toolbox subsystem (Window Manager, Event Manager, QuickDraw II, Menu
Manager, File Manager, Scrap Manager, ...) is a candidate for native
rewrite. The order will be chosen by which seam hurts most first, but a
likely sequence:

1. **Scrap Manager** — the simplest seam; already half-cut by the broker's
   shared clipboard.
2. **File Manager** — exposes the shared filesystem natively rather than
   through the virtual-disk fiction.
3. **Event Manager** — lets the radial keyboard and touch surface inject
   events without being trapped through the 65C816 interrupt model.
4. **QuickDraw II** — the big one. Native QuickDraw II lets us render at
   panel resolutions other than 320×200 and frees us from the Super
   Hi-Res palette constraint per application's choice.

Each native subsystem coexists with the still-emulated remainder; the
broker arbitrates calls across the boundary.

## two parallel modification surfaces

We can modify the stack at two levels at once:

- **At the GS/OS source level.** Apple's release covers the bulk of the OS
  above the Toolbox. We rebuild from source under our own toolchain
  (ca65 or merlin32 for 65C816 assembly), package as a disk image, boot
  it in GSplus. This is the primary modification surface.
- **At the Toolbox ROM level.** The Toolbox lives in ROM, not in GS/OS.
  Apple did not release Toolbox source. Modifications here require
  disassembly and binary patching. We do this only where the source-level
  approach can't reach.
- **At the emulator level.** GSplus itself is C and we can add new
  device emulations (the broker-as-peripheral), new framebuffer outputs
  (RG DS panels), or short-circuit specific Toolbox traps natively.

These three surfaces are coordinated by always going through the broker as
the integration point.

## diagram (ascii)

```
   ┌─ top panel ─────┐    ┌─ bottom panel ──┐
   │   screen A      │    │   screen B      │
   │  (IIgs #1)      │    │  (IIgs #2)      │
   │   GS/OS  +      │    │   GS/OS  +      │
   │   our patches   │    │   our patches   │
   └────────┬────────┘    └────────┬────────┘
            │                      │
            └─────┐         ┌──────┘
                  │         │
              ┌───┴─────────┴───┐
              │  broker (LuaJIT)│
              │  - shared FS    │
              │  - clipboard    │
              │  - IPC          │
              │  - input router │
              │  - radial kbd   │
              └────────┬────────┘
                       │
              ┌────────┴────────┐
              │  GSplus (×2)    │
              │  (our fork)     │
              └────────┬────────┘
                       │
              ┌────────┴────────┐
              │ Linux on RK3568 │
              │ (Anbernic RG DS)│
              └─────────────────┘
```

## what each layer must not know

- Layer 3's GS/OS must not know about layer 1. The emulated IIgses see
  only the broker (eventually as a real GS/OS device).
- Layer 2 must not poke directly into emulator internals; it talks to each
  emulator through a defined virtual-peripheral interface. This is the
  same interface a native subsystem rewrite would use later, which keeps
  the seam clean.
- Layer 1 is unaware that layer 2 exists; the broker runs as an ordinary
  Linux process.
