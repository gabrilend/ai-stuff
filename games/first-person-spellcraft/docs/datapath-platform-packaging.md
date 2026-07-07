# Datapath — Platform & Packaging (Phase 9)

> How the finished game gets from a developer's LuaJIT source tree onto a small
> machine in a stranger's hands. This is the **delivery** datapath: it does not
> add new gameplay, it moves the whole existing game across a gap and reshapes it
> to fit the far side.
>
> Sibling docs: [roadmap.md](roadmap.md) (why Phase 9 depends on everything),
> [vision-overview.md](vision-overview.md) (target platforms, language policy),
> [table-of-contents.md](table-of-contents.md) (the index — it already
> forward-declares this file; this doc does not edit it).
>
> Per project discipline, **no hardware numbers are hardcoded here.** Anbernic
> ships many models with different chips, RAM, and screens. Where a real figure
> is needed, this doc points at the *hardware probe* / *budget validator* tools
> described below, which read the true numbers off the device (or its spec sheet)
> on demand. Hard numbers rot; a probe does not.

---

## The one-paragraph picture

The build takes the whole game — the LuaJIT source of Phases 1–8 plus its assets
— and folds it into a single **distributable artifact** shaped for one target
machine. The primary machine is an **Anbernic handheld**: a small ARM Linux
device with a gamepad and no mice. Three of the target's properties bend what can
ship: its **CPU/RAM budget** (how much game fits and how fast the Doom-style loop
runs), its **display** (small fixed screen), and its **input** (a gamepad, so the
signature two-mouse aim must fall back to a stick). A separate, whimsical branch
encodes the same game/data as **audio on a cassette**, read back through a
**gameboy control interface** into a **pico-8-style** player. The whole thing is
given away — "one copy to each european" — as a gift, not a product.

---

## Main datapath — source tree to a hand

```
   DEVELOPER SIDE (a normal computer)                 TARGET SIDE (the handheld)
   ┌───────────────────────────────┐
   │  LuaJIT source (Phases 1–8)    │
   │  + assets (maps, art, sound,   │
   │    spell/puzzle/NCP data)      │
   └───────────────┬───────────────┘
                   │
                   v
        ┌──────────────────────┐   reads   ┌──────────────────────────┐
        │  HARDWARE PROBE /     │<─────────►│  target hardware profile │
        │  BUDGET VALIDATOR     │           │  (arch, RAM, screen,     │
        │  (measures, never     │           │   input kind, CPU class) │
        │   assumes)            │           └──────────────────────────┘
        └──────────┬───────────┘
                   │  profile in hand, the pipeline knows what to build for
                   v
        ┌──────────────────────┐
        │  ASSET BUNDLER        │  gathers every ${DIR}-relative asset,
        │                       │  normalizes paths, drops dev-only files
        └──────────┬───────────┘
                   │
                   v
        ┌──────────────────────┐
        │  BUILD / CROSS-BUILD  │  LuaJIT-on-ARM: bytecode + native libs for
        │  (target = ARM Linux) │  the target's chip, not the dev machine's
        └──────────┬───────────┘
                   │
                   v
        ┌──────────────────────┐
        │  PACKAGE / IMAGE      │  one installable artifact for the handheld
        │  (app dir or image +  │  (its launcher / manifest the device menu
        │   portable launcher)  │  understands)
        └──────────┬───────────┘
                   │  copy the artifact onto the device (SD card / storage)
                   v                                    ┌────────────────────────┐
                                            installs →  │  PORTABLE LAUNCHER      │
                                                        │  (${DIR} convention:    │
                                                        │   runs from any dir,    │
                                                        │   all paths relative)   │
                                                        └───────────┬────────────┘
                                                                    │ launches
                                                                    v
                                                        ┌────────────────────────┐
                                                        │  THE GAME, RUNNING      │
                                                        │  under the target's     │
                                                        │  CPU/RAM/screen budget  │
                                                        └───────────┬────────────┘
                                                                    │ needs aim +
                                                                    │ movement
                                                                    v
                                            ┌───────────────────────────────────────┐
                                            │  SEAM BACK TO PHASE 2 (input)           │
                                            │  the handheld has a GAMEPAD, no mice —  │
                                            │  see "Input seam" below                 │
                                            └─────────────────────────────────────────┘
```

Read the arrows as data moving: source + assets flow rightward, are **measured
against** the target profile, **bundled**, **built for the target's chip**,
**packaged** into one artifact, carried across the gap, **installed**, and
**launched** — where the running game meets the target's constraints, chief among
them its input.

---

## Input seam — the join back to Phase 2

This is the single most important cross-phase connection in Phase 9, and it is a
**seam, not a redesign.** Phase 2 built an *input abstraction layer*: a boundary
that turns raw devices into an aim/hand intent the rest of the game reads, so no
gameplay code cares which physical device produced the aim. Phase 2 owns that
interface. Phase 9 only adds a **new source behind it**.

```
   PHASE 2's input abstraction layer (owns the interface)
   ┌───────────────────────────────────────────────────────────┐
   │  aim / hand-intent  ◄── (whatever source is present) ◄──   │
   └───────────────────────────────────────────────────────────┘
        ▲                    ▲                         ▲
        │                    │                         │
   two-mouse            (BCI stretch,             GAMEPAD SOURCE   ← added by
   boomstick             documented only)         (Phase 9)          Phase 9
   (desktop, signature)                           on the handheld
```

On a desktop, the two-mouse boomstick fills the aim intent. On the handheld there
are no mice, so a **gamepad source** fills the *same* intent — the signature
dual-mouse aim **degrades gracefully** to a single-stick (or twin-stick) aim. The
degradation ladder, richest to leanest:

- **Two mice** — the full boomstick, two hands driven independently. (desktop)
- **Twin stick** — one stick per hand where the pad has two sticks.
- **Single stick + modifier** — one stick aims; a shoulder button switches which
  hand it drives, or binds the off-hand to a coarser assist.

The rule: gameplay code upstream never learns which rung it is on. It always
reads "aim intent" from Phase 2's layer. Phase 9 supplies the rung, and the
hardware profile (below) decides which rung the target can reach. This doc
**describes** that interface; the interface itself is Phase 2's to define — see
[datapath-dual-mouse-input.md](datapath-dual-mouse-input.md).

---

## Experimental branch — cassette → gameboy → pico-8

A separate, **sacrosanct whimsy** branch, quoted from the vision verbatim:

> oh! what if we made it run on a cassette and we hooked up a cassette tape
> player to a gameboy control interface and used the binary "sounds" it made to
> record the game in the style of a pico-8

This is an *exploratory* delivery path, not the shipping one. It is documented so
it is never lost, and clearly marked experimental so nobody blocks the Anbernic
release on it. Its datapath is its own line, forking off the same built game/data:

```
   built game / data  ──►  AUDIO ENCODER  ──►  cassette tape  (binary "sounds")
   (or a pico-8-sized       (bytes → tones,      recorded, physical
    slice of it)            pico-8 style)        object

        the tape, played back later:

   cassette player  ──►  gameboy control interface  ──►  AUDIO DECODER  ──►  the
   (tones out of        (reads the tones as its         (tones → bytes)     game
    the tape head)       control/data input)                                loads,
                                                                            pico-8
                                                                            style
```

Two honesties this branch must keep, both flagged loud in its issue:

- The full Phases 1–8 game almost certainly **does not fit** the data budget of
  an audio cassette read this way. So the branch targets a **pico-8-sized slice**
  — a tiny playable demake — not the whole game. This is a warning, per the "no
  quiet fallbacks" rule, not a silent shrink.
- The gameboy-control-interface link is **hardware exploration.** Its feasibility
  is an open question; the issue treats it as a research spike with a
  clearly-stated "here is what we do not yet know."

---

## The spirit of delivery — a gift, not a product

The vision fixes the distribution intent: **"give one copy to each european."**
That framing — free, anti-commercial, a gift — is part of the vision's
socialist-utopia voice and is preserved as such. Packaging choices bend toward
**giving away**: no DRM, no store lock-in, an artifact anyone can copy onto a
cheap SD card and hand to the next person. The datapath's last step is a copy
that costs nothing to make again. ("I'm not interested in product.")

---

## Structures, functions, tools — by role

Named in plain English by what they *do*. Nothing here hardcodes a device number;
the probe and validator supply live figures.

### Data structures (by role)
- **Target hardware profile** — the measured description of one target machine:
  CPU class, available RAM, screen size, and *which kind of input it has* (mice /
  gamepad / stick count). Everything downstream reads this instead of guessing.
- **Performance budget** — the envelope the running game must stay inside on that
  target: frame-time ceiling, memory ceiling, asset-size ceiling. Derived from
  the profile, not typed in by hand.
- **Bundle manifest** — the list of every asset and code file that goes into the
  artifact, all paths ${DIR}-relative, dev-only files excluded.
- **Package / image descriptor** — how the artifact presents to the device menu:
  its launcher, its icon, its metadata.
- **Input-source binding (gamepad)** — the mapping from gamepad controls to the
  aim/hand intent Phase 2's layer expects; carries which **degradation rung** it
  represents.
- **Cassette encoding descriptor** *(experimental)* — parameters for turning
  bytes into pico-8-style tones and back: which slice of the game, the tone
  scheme, the framing.

### Functions (by role)
- **Probe the target** — read a device's (or spec sheet's) real CPU/RAM/screen/
  input and fill a hardware profile. Measures; never assumes.
- **Derive the budget** — turn a profile into a performance budget.
- **Validate against budget** — check a candidate build fits the budget; a
  failure is a loud error (over budget), never a silent trim.
- **Gather the bundle** — walk the ${DIR}-relative asset tree into a manifest.
- **Build for the target** — produce LuaJIT-on-ARM artifacts for the target chip.
- **Package the artifact** — fold bundle + build into one installable image/app.
- **Bind the gamepad source** — register the handheld gamepad as a source behind
  Phase 2's input layer, at the richest degradation rung the pad supports.
- **Encode / decode to audio** *(experimental)* — bytes ↔ pico-8-style tones for
  the cassette branch.

### Tools / scripts (by role, + why)
- **Hardware probe** — *why:* keeps every number honest and current; the one
  place device facts enter the pipeline.
- **Budget validator** — *why:* stops an over-budget build from ever reaching a
  handheld, and prints *why* it failed rather than shrinking things quietly.
- **Asset bundler** — *why:* one deterministic gather so the artifact is
  reproducible and path-portable.
- **Cross-build driver** — *why:* the dev machine is not the target; this is where
  LuaJIT-on-ARM concerns live.
- **Packager / image builder** — *why:* produces the single thing you copy to a
  device.
- **Portable launcher script** — *why:* honors the ${DIR} convention so the game
  runs no matter which folder it was launched from — the discipline that makes
  handheld and cassette packaging honest.
- **Phase-9 demo launcher** — *why:* the phase demo (in `issues/completed/demos/`)
  showing the packaging path end to end, per the roadmap's demo discipline.
- **Cassette encoder/decoder + gameboy-interface spike** *(experimental)* —
  *why:* keeps the whimsy alive as a research artifact without gating the release.

---

## Where this plugs into the rest of the project

- **Depends on all prior phases** — Phase 9 packages the *whole* game; it cannot
  ship what Phases 1–8 have not built. See the dependency graph in
  [roadmap.md](roadmap.md).
- **Phase 2 (input)** — the load-bearing cross-phase seam; the gamepad enters as a
  new source behind Phase 2's abstraction. See
  [datapath-dual-mouse-input.md](datapath-dual-mouse-input.md).
- **Phase 6 (local AI DM)** — the heaviest tenant of the performance budget; the
  handheld's RAM/CPU is the reason its local-model constraints were meant to be
  honored since Phase 1. The budget validator is where that pressure shows up.
- **Language policy** — LuaJIT-compatible syntax throughout is what keeps the door
  open to ARM and to the pico-8-style cassette experiment. See
  [vision-overview.md](vision-overview.md#language).

The Phase 9 issue files (`issues/901-*.md` … `issues/906-*.md`) build each box in
the diagrams above, foundation first.
