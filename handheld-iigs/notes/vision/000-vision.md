---
name: handheld-iigs vision
status: draft (planning phase, 2026-05-19)
---

# vision

A port of the **Apple IIgs** (1986) to the **Anbernic RG DS**, a dual-screen
ARM handheld. Not a single emulator window on a portable — a re-imagining
of what a personal computer feels like when you carry two coordinated color
desktops in your hands, both of which you can crack open and rewrite at the
OS level.

## the shape of the machine

Two screens. Two desktops. One person.

Each screen runs its own IIgs, and the pair share a single backing store
underneath. You can drag a file from one desktop to the other. You can copy
on the left and paste on the right. You can run a game on one while editing
in AppleWorks on the other.

This is not a thing the 1986 IIgs could do. That is the point.

## why Apple IIgs (and not Apple II or Mac Plus)

We weighed three candidates from the same family. The IIgs won on three
overlapping criteria:

- **Color.** The original Apple II had color from 1977 (40×48 lo-res, 280×192
  hi-res with NTSC artifacting; the IIe extended this to 560×192 double
  hi-res with 16 colors). The IIgs is not the *earliest* color Apple, but it
  is the *most* colorful pre-Mac-II Apple: **Super Hi-Res 320×200 with 16
  colors per scanline, picked from a 4096-color palette** — and the per-line
  palette means the effective onscreen color count is much higher than 16.
- **A real GUI OS.** GS/OS has a Finder, a Toolbox, windows, menus, and
  mouse-driven input. The dual-desktop architecture we want maps directly
  onto two GS/OS instances; on a stripped-down Apple II we would have to
  invent the whole windowed-desktop fiction ourselves.
- **Sound that sings.** The Ensoniq 5503 is a 32-oscillator wavetable
  synthesizer — not a beep speaker. Music software for the IIgs is
  genuinely musical.

The Mac Plus considered yesterday loses on color (1-bit mono) but has a
better-documented Toolbox. The IIgs Toolbox is also documented (Apple
released the GS/OS source publicly), and the color gain is decisive.

## the geometry coincidence

The RG DS panels are 640×480 each. The IIgs Super Hi-Res framebuffer is
320×200. That is **exactly 2× integer scaling to 640×400** with 80 pixels
of letterbox space left at the bottom — enough for a thin status strip
without compressing the emulated picture. No bilinear filtering, no aspect
distortion, no lying about what the original machine drew.

## OS-level modification, not just emulation

This project is **not** a clean retro-faithful emulator. Apple released the
GS/OS system software source code publicly, which means:

- We can rebuild GS/OS from source under our own toolchain.
- We can modify the Finder, the desktop, the Event Manager, the Scrap
  Manager — any of it — and boot the modified version on the device.
- We can patch the IIgs Toolbox ROM (harder, requires disassembly, but
  feasible).

The emulator we choose (**GSplus**, a BSD-licensed fork of KEGS) is also
open source, so the *bottom* of the stack is editable in tandem with the
*top*: changes to GS/OS can be paired with custom emulator hooks that
make the modifications efficient.

This is what makes the dual-desktop story tractable. The two-Macs-talking-
through-a-broker design we sketched yesterday becomes the two-IIgses-
talking-through-a-broker design, and the broker can present itself to GS/OS
as a *real GS/OS device driver* — not a virtual disk fiction — once we
modify GS/OS to know about it.

## the input shape

The handheld has no keyboard. We invent one.

A **radial dual-stick keyboard**: the left stick picks a region of the
alphabet; the right stick picks a character within that region. The bottom
screen renders a visual radial menu so you can see what you're aiming at.

Touch becomes the mouse. The RG DS has multi-touch with capacitive stylus
support on **both** panels — better than expected. The stylus is the right
fit for GS/OS's small click targets (close-boxes, scroll arrows).

## the architectural shape

**Option C, the hybrid path.** Two GSplus instances, one per screen,
brokered by a thin LuaJIT host layer underneath that owns the shared
filesystem, the shared clipboard, and an IPC channel.

Each IIgs inside its emulator is still cooperatively single-tasked, as
GS/OS ever was. Multitasking is **between** the two IIgses, not within
either. This is an accepted trade for the planning phase.

The seam between emulator and broker is where future native rewrites
enter: Scrap Manager, File Manager, Event Manager, QuickDraw II — pick one
Toolbox subsystem at a time and replace it with a native ARM implementation
that the other (still-emulated) half can talk to through the broker.
Theseus's ship, replanked one beam at a time.

## what depends on what is not yet built

In-emulator multitasking, and any form of parallelism finer than one-thread-
per-emulator, will land on top of the threading primitives currently being
developed at `/home/ritz/programs/sora/soramech/`. Until that work is done,
documents in this project describing "multithreaded by default" or
"intra-emulator parallelism" carry a **pending soramech** marker and must
be re-read and corrected once the upstream primitives stabilize.

## what is in scope, eventually

- Native boot to two GS/OS desktops
- Real IIgs software running unmodified (games, productivity, music tools)
- A modified GS/OS that knows about the second desktop and the radial input
- Custom games and applications written **for this OS specifically**,
  exploiting both screens, the radial input, the stylus, and (eventually)
  the gyroscope and vibration motor
- Patches to the IIgs Toolbox ROM where the source-level approach can't
  reach (the Toolbox lives in ROM, not in GS/OS proper)
- A documentation site (HTML at `docs/HTML/`) that lets a reader hop from
  any page to any other page

## what is not in scope

- Hardware-accelerated 3D. The original IIgs rendered everything in
  software to its 320×200 framebuffer; that is the contract we keep.
- Networking the device to other machines off the handheld. The RG DS has
  WiFi 802.11ac and Bluetooth 4.2; we may use them later, but not in the
  early phases.
- Pretending we are a faithful museum-piece emulator. We are not. We are
  an opinionated rewrite of a 1986 computer for a 2026 device.
