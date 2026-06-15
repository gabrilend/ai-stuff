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
4. **Routes input and tracks the last-input target.** Touches on a
   screen go to that screen's emulator. Stylus input is treated the
   same as touch (the RG DS exposes both through the same digitizer).
   Stick input routes to whichever screen is the current last-input
   target — a (screen, window, program) triplet the broker updates
   on every input event. The radial-keyboard renderer draws its
   overlay on the **inactive** screen (the one *not* receiving input),
   so the user can see the guide without obscuring the thing they're
   typing into. See `docs/003-input-system.md` for details.
5. **Implements an IPC channel** between the two emulators so that
   custom-written applications can coordinate explicitly across screens.
   The channel is modeled on AppleTalk but rides on a Unix-domain socket
   underneath; both endpoints look like network sockets to GS/OS code.
6. **Mixes audio.** Each emulated program owns its own stereo channel.
   The broker mixes the two Ensoniq 5503 outputs (one per emulator)
   plus per-program panning into the device's stereo speakers or
   headphone jack. Defaults: each emulator's programs pan slightly
   left/right based on which screen they live on, but this is fully
   configurable. The two Ensoniqs running in parallel give 64 total
   wavetable voices.
7. **Plays the boot chime exactly once.** On power-on the broker plays
   the //gs boot chime through the mixer, then suppresses the second
   emulator's chime by muting its audio output for ~2 seconds during
   boot. The user hears the iconic chime, not a double-chime.

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

## modification surfaces

We can modify the stack at four levels. **None of these surfaces involve
rebuilding GS/OS from source.** Apple never officially released GS/OS
source; the well-known 2013 leak now archived publicly cannot be used as
a build input under our license posture (see *operational constraints*
below). The leaked source is permissible as a **research reference only**
— we read it to understand ABIs and call structures, we do not assemble
or ship from it.

- **At the GS/OS disk-image level (binary patching).** GS/OS ships as
  binary system files on a `.2mg` disk image. We apply byte-level patches
  to a working copy of the user-supplied image. The original `.2mg` is
  never modified — a patched copy is produced per build. This is the
  primary surface for *modifying* existing GS/OS behavior during staging.
- **At the disk-image level (injected drivers and CDevs).** New
  functionality we author from scratch in 65C816 assembly — Device Manager
  drivers, Control Panel devices (CDevs), startup files — is assembled
  on the host with a 65C816 cross-assembler and *added* to the patched
  disk image. This is the primary surface for *adding* new OS-level
  functionality during staging.
- **At the Toolbox ROM level.** The Toolbox lives in ROM, not in GS/OS.
  Apple never released Toolbox source. Modifications here require
  disassembly and binary patching of a working copy of the ROM image.
  Reserved narrowly; phase 8+.
- **At the emulator level.** GSplus itself is C and we can add new
  device emulations (the broker-as-peripheral), new framebuffer outputs
  (RG DS panels), or short-circuit specific Toolbox traps natively.
- **At the bare-metal level (eventual destination).** After phase 11,
  the entire system runs in ARM assembly on the RK3568 with no Linux
  underneath. The 65C816 modifications and injected drivers from staging
  become ARM assembly modules. Threading primitives are imported
  wholesale from soramech. This is the destination the project converges
  on; see `docs/004-roadmap.md` phases 11–12.

The surfaces are coordinated by always going through the broker as
the integration point. The patch-convention discipline
(`docs/005-patch-conventions.md`) keeps each surface independently
modifiable and the cross-surface coordination explicit.

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

## what this architecture explicitly does not support

**Programs that render on both screens at once.** Each screen is its own
self-contained IIgs with its own GS/OS, its own Window Manager, its own
applications. A single program cannot draw on the other screen's
framebuffer, because from its perspective the other screen does not
exist — there is only "its" IIgs and a broker peripheral.

This is a deliberate constraint, not a limitation we plan to lift. Two
reasons:

1. **It keeps the broker architecture honest.** The two emulators are
   peers; neither is master, neither has a privileged view of the
   other's framebuffer. If we wanted spanning programs, the broker
   would have to become a compositor, and the symmetry would break.
2. **It avoids touching the ROM-resident Window Manager.** Cross-screen
   geometry would require modifying the Toolbox ROM's windowing code,
   which is the hardest modification surface available (Apple never
   released the Toolbox source; it would have to be disassembled and
   binary-patched).

When a feature wants "both screens at once" — a game where one screen
is the map and the other is the action view, a music app where one
screen is the keyboard and the other is the sequencer, a journal where
one screen holds the page and the other holds the radial keyboard —
the model is **two cooperating programs**, one running on each IIgs,
exchanging state through the broker IPC channel. The user sees a unified
dual-screen experience; the two IIgses see two ordinary programs that
happen to coordinate.

## operational constraints

A small collection of constraints that shape the system at every layer
and are worth stating explicitly so they don't get rediscovered:

- **Suspend to RAM, never to SD.** The Hall sleep switch pauses both
  emulators; on wake, they resume from in-memory state. We never
  serialize emulator state to disk for sleep, because the SD card has
  a finite write lifetime and our threading model gives us no good
  moment to flush atomically.
- **Minimize SD-card writes generally.** Frequent small writes shorten
  the card's life and create latency spikes. `tmp/` is RAM-backed (a
  symlink to `/tmp/apple-IIds`). The broker coalesces writes and
  flushes only when necessary. A future analysis
  (`issues/pending/iigs-write-frequency-analysis.md`) will profile
  GS/OS's own write patterns and inform what we can intercept.
- **Cross-machine file locking is option A.** If screen A has `MyDoc`
  open for write, screen B's attempt to open the same file gets a
  clear error. No silent read-only, no diverging copies, no
  Google-Docs-style live co-editing (at least not yet).
- **License posture: third-party-deployment-ready.** We assume someone
  else will build the image on their own RG DS. Anything with a
  non-OSI-approved or otherwise unclear license stays out of git. The
  user supplies their own Apple //gs ROM and their own GS/OS `.2mg`
  separately — neither is redistributable. The leaked GS/OS source is
  reference material; nothing assembled from it ships. This biases us
  toward permissive (BSD, MIT, Apache) over copyleft for our own code.
- **Boot chime exactly once.** Two emulators want to play the //gs
  chime on boot; the broker suppresses one. See broker responsibility
  7 above.
