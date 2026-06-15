---
name: Apple IIds vision
status: draft (planning phase, 2026-05-19)
---

# vision

**Apple IIds** is a modernized Apple //gs (1986) running on the Anbernic
RG DS, a dual-screen ARM handheld. The name is a pun on the DS hardware.
The work is a port of GS/OS — carefully, in modernized 65C816 then ARM
assembly — onto a 2026 device, with threading primitives lifted from
soramech and an in-device development environment that lets you write new
programs in ARM assembly directly on the handheld.

## the destination

By the time this project is "done" (multi-year), the device boots into
the Apple IIds operating system **directly on the bare metal**. No Linux
underneath. No GSplus emulator. The IIgs's 65C816 assembly has been
ported, translated, or selectively rewritten in ARM assembly so that
what runs on the RK3568 is the real Apple IIds — a modernized GS/OS
with preemptive multithreading and modern hardware connections.

The user picks up the device, presses power, hears one boot chime, and
is looking at two coordinated GS/OS desktops, one per screen. They write
programs in soramech's editor, which is a first-class in-device IDE
that emits ARM assembly. The programs are first-class Apple IIds
applications and indistinguishable from anything else running on the
machine.

This is the destination. Most of what's documented elsewhere is the
**staging ground** — the path to get there.

## the staging ground (years 0–N)

Until bare-metal lands, we run two **GSplus** emulator instances on
Linux on the RG DS, brokered by a thin LuaJIT process. Each emulator
runs a real Apple //gs ROM and a GS/OS `.2mg` disk image the user
supplies. Apple never officially released GS/OS source, so we modify
the OS via binary patches to the disk image plus our own Device Manager
drivers and CDevs assembled from 65C816 source we author. The broker
mediates a shared filesystem, a shared clipboard, IPC between the
screens, and input from the radial dual-stick keyboard + touch + stylus.

The staging ground is itself useful: the device is usable, real
software runs, applications exist. The staging ground is what gets
called "phase 1 through 10" of the roadmap. Bare-metal is phase 11;
the soramech editor as in-device IDE is phase 12.

## the shape of the machine

Two screens. Two desktops. One person.

Each screen runs a self-contained Apple IIds with its own GS/OS, its
own Window Manager, its own applications. **No single program ever
renders on both screens** — that's a hard rule (see
`docs/001-architecture-overview.md` for why). Where a feature wants
"both screens at once," the model is a **coordinated pair** of
programs: one ordinary IIds application per screen, talking through
the broker IPC channel.

## why Apple //gs

The IIgs won out over Apple II, Mac Plus, and Apple //e on three
overlapping criteria:

- **Color.** Super Hi-Res 320×200 with 16 colors per scanline, picked
  from a 4096-color palette — and the per-line palette means the
  effective onscreen color count is much higher than 16. The IIgs is
  the *most* colorful pre-Mac-II Apple, not the *earliest*; the
  original Apple II had color from 1977.
- **A real GUI OS.** GS/OS has a Finder, a Toolbox, windows, menus,
  and mouse-driven input. Maps directly onto two desktops.
- **Sound that sings.** The Ensoniq 5503 32-oscillator wavetable.
  Two of them, in the dual-screen world.

The IIgs also has its system software source publicly released by
Apple, which is what makes bare-metal viable. Without that, we'd be
stuck reverse-engineering, pushing the moonshot from "multi-year" to
"decade."

## the geometry coincidence

The RG DS panels are 640×480 each. The IIgs Super Hi-Res framebuffer is
320×200. That is **exactly 2× integer scaling to 640×400** with 80
pixels of letterbox left at the bottom of each panel — enough for a
thin status strip without compressing the picture. No bilinear
filtering, no aspect distortion, no lying about what the original
machine drew.

## the input shape

The handheld has no keyboard. We invent one.

A **radial dual-stick keyboard**: the left stick picks a region of the
alphabet; the right stick picks a character within that region. The
**inactive** screen — the one not currently receiving input — renders
the visual radial menu, so you can see what you're aiming at without
obscuring the thing you're typing into.

A **one-handed mode**: when the user has a stylus in one hand and only
the other thumb on the device, the left stick still picks a wedge but
the right stick is replaced by **tapping the displayed radial menu
with the stylus**. The visible menu becomes its own touch target. Same
UI, different commit gesture.

The broker tracks the **last-input target**: which screen, which
window, which program received the most recent input event. Newly
emitted characters route there. When focus changes (Start button, or
the user touches a different screen), the overlay flips to the
newly-inactive screen.

Touch + stylus together become the mouse. Both RG DS panels support
multi-touch and stylus separately. Stylus is recommended for GS/OS's
small click targets.

## threading by default

Apple IIds is preemptively multitasking. Within a single screen's
GS/OS, programs run concurrently. This is **not** how the 1986 GS/OS
worked (it was cooperative), and the change is structural — the
Toolbox must become reentrant, every shared global thread-safe, every
interrupt path re-examined.

The threading primitives are **lifted from soramech**, minus its
language-spec system. We already have the language: it's assembly
(65C816 during staging, ARM after bare-metal). What we take from
soramech: scheduler, locks, channels, the message-passing primitives
that make concurrent work safe.

The threading work is done **carefully, in assembly**. Not C with
hand-rolled inline asm. The point is to keep the system honest: every
synchronization primitive is visible at the lowest level.

## in-device programming

The development environment for Apple IIds is **soramech's editor**,
running on the device itself. Programs are written in ARM assembly
(the language of the destination machine). They are first-class
applications.

This makes the device **self-hosting**: someone with only the device
can write new programs for it, with no laptop in the loop. This is a
goal that shapes every earlier decision — it's why we care about
threading-as-OS-primitive, why we don't lock the OS down with C
runtimes that fight assembly, why the bare-metal port is core rather
than aspirational.

## OS-level modification is how everything happens

This is **not** a faithful retro-museum emulator. Every piece of the
stack is editable in tandem:

- **GSplus** (the staging-ground emulator) — BSD-licensed, C. Edited
  via the patch convention in `docs/005-patch-conventions.md`.
- **GS/OS source** — released publicly by Apple, 65C816 assembly.
  The primary modification surface during staging.
- **Toolbox ROM** — not source-released. Modified rarely, via
  disassembly and binary patching. Reserved for things GS/OS source
  cannot reach.
- **Bare-metal port** (eventual) — the destination. Everything is ARM
  assembly; threading is first-class; soramech's primitives are
  imported wholesale.

## what depends on what is not yet built

Two upstream dependencies:

- **soramech** (`/home/ritz/programs/sora/soramech/`) — the threading
  primitives we'll lift. Anything labeled **pending soramech** is
  design-only until that stabilizes.
- **The Apple GS/OS source release license terms** — we treat this
  project as if a third party will deploy it on their own RG DS.
  License diligence on Apple's release happens before any of it lands
  in git. Anything whose license is unclear or non-OSI-approved stays
  out.

## what is in scope

- Two coordinated GS/OS desktops on the RG DS, today via emulation,
  eventually bare-metal
- The radial dual-stick keyboard, with inactive-screen overlay and
  one-handed stylus-tap mode
- Last-input tracking (which screen / window / program receives the
  next character)
- Threading-by-default in modernized assembly, primitives from
  soramech
- Soramech editor as the in-device IDE (post-bare-metal)
- A modified GS/OS that knows about the broker as a first-class device
- Toolbox ROM patches where source-level cannot reach
- Custom games and applications written for this OS specifically —
  always single-screen programs, optionally paired through the broker
  for dual-screen experiences
- A documentation site (HTML at `docs/HTML/`) hopping between any page
  and any other page

## what is not in scope

- **Programs that span both screens.** Each screen runs a
  self-contained IIds with its own Window Manager; cross-screen window
  geometry would require Toolbox ROM modifications we won't do.
  Coordinated pairs only.
- **Hardware-accelerated 3D.** The IIds renders everything to a
  320×200 framebuffer in software; that contract is preserved on bare
  metal too.
- **A faithful museum-piece emulator.** Apple //gs at original speed
  is not the target. The target is **a modernized Apple //gs** — same
  ergonomics, modern performance, threading, modern hardware
  connections.
- **License-ambiguous code in git.** Default-deny anything not clearly
  OSI-approved.

## software wishlist (what "phase 1 done" means in practice)

Posture: **everything should run.** The wishlist is just what we
explicitly verify before saying phase 1 is done:

- a document editor (e.g. AppleWorks GS, Teach)
- a paint program (e.g. Platinum Paint, DeluxePaint II)
- a game (visually punchy — TBD)
- a music player or tracker (NoiseTracker GS, MCS-GS)
- a tech demo or two (Cogito, Task Force, Modulae)

## the boot chime

The Apple //gs chime is iconic. We keep it. **Exactly one chime per
power-on**, despite two emulated IIdses — the broker plays the chime
once and suppresses the second emulator's chime by muting its audio
output for the first ~2 seconds of boot.

## the directory name

The project lives at `/mnt/mtwo/programming/ai-stuff/apple-IIds/`. The
prior names (`handheld-apple-II`, `handheld-mac-plus`, `handheld-iigs`)
are fossils from earlier planning days, preserved in the decision log
at `issues/phase-1-progress.md`.
