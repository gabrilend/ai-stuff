# phase 1 — progress

Status as of 2026-05-19: **planning** (no code yet)

## issues

| id  | name                       | status   | blockedBy       |
|-----|----------------------------|----------|-----------------|
| 101 | source and toolchain       | pending  | —               |
| 102 | project build system       | pending  | 101             |
| 103 | single screen boot         | pending  | 102             |
| 104 | touch as mouse             | pending  | 103             |
| 105 | disk image management      | pending  | 103             |
| 106 | GS/OS source toolchain     | pending  | 101             |
| 120 | phase 1 demo               | pending  | 101, 102, 103, 104, 105, 106 |

## phase goal

One Apple //gs (the staging-ground machine), booting GS/OS on screen A
of the Anbernic RG DS, mouseable by touch and stylus, with the ability
to insert and eject disk images at runtime — and crucially, **booting
from a GS/OS image we built ourselves from Apple's publicly released
source**. Closed by issue 120's demo.

Phase 1 is the foundation of the **staging-ground** half of the project
(phases 1–10 run on Linux with GSplus emulators). The **destination**
half (phases 11–12) is bare-metal Apple IIds on the RK3568 with no
Linux, and is its own multi-year undertaking.

## open hardware questions (block 101)

- `/dev/input/eventN` mapping for: top-panel digitizer, bottom-panel
  digitizer, left analog stick, right analog stick, d-pad, face buttons,
  shoulder buttons, the two Start buttons, the two Select buttons,
  volume keys, stick clicks (L3 / R3).
- `/dev/fb*` or DRM/KMS device(s) for the two 640×480 panels.
- USB-C port semantics in practice (which is host-mode, which is OTG,
  whether either supports both).
- Stylus differentiation: does the digitizer report stylus separately
  from finger?
- Gyroscope IIO device path and precision.

## decisions made so far

- **2026-05-18 (yesterday)** — initial pick was Mac Plus; project dir
  was named `handheld-apple-II` then renamed to `handheld-mac-plus`.
- **2026-05-19** — switched target from Mac Plus to **Apple IIgs**.
  Project dir renamed `handheld-mac-plus` → `handheld-iigs`.
  Reasons: color (Super Hi-Res 320×200 with 16-from-4096-palette per-line),
  Ensoniq 5503 sound, real GUI OS (GS/OS) with a Finder and a Toolbox,
  Apple released the GS/OS system software source publicly (so OS-level
  modifications are tractable, not just emulator-level patches).
  Correction worth recording: the IIgs is the *most colorful* pre-Mac-II
  Apple, **not** the *earliest* color Apple — the original Apple II had
  color from 1977.
- **2026-05-19** — project name renamed to **Apple IIds** (a pun on the
  RG DS hardware). Dir renamed `handheld-iigs` → `apple-IIds`. The
  product is the modernized GS/OS we're shipping; the historical Apple
  //gs (1986) keeps the IIgs spelling. The two are distinct in docs.
- **2026-05-19** — **bare-metal port** confirmed as a core constraint
  of the project, not aspirational. The destination is the Apple IIds
  OS running natively on the RK3568 with no Linux underneath. Threading
  primitives are lifted wholesale from soramech (minus its language-
  spec system); all threading work is in assembly. After bare-metal,
  the in-device IDE is soramech's editor, which emits ARM assembly.
  Roadmap grew from 9 phases to 13 to capture this (new phases 8, 9,
  11, 12).
- **2026-05-19** — smaller decisions encoded: suspend-to-RAM only (no
  SD writes for sleep state); audio mixer with per-program stereo
  channel ownership; one boot chime per startup despite two emulators;
  cross-machine file locking option A (second opener gets an error);
  third-party-deployment license posture (default-deny non-OSI code).
- **2026-05-19** — pinned hardware target: **Anbernic RG DS**.
  RK3568 quad-core A55 @ 2 GHz, 3 GB RAM, two 4″ IPS panels at 640×480
  with multi-touch + stylus, two clickable analog sticks, dual Start /
  Select pairs (one per screen). The 320×200 → 640×400 2× integer scale
  is the geometry coincidence that makes the panel mapping clean.
- **2026-05-19** — chose **GSplus** (BSD-licensed KEGS descendant) over
  KEGS itself and over MAME's IIgs driver. Reason: SDL2 abstraction
  makes panel-framebuffer retargeting tractable; BSD license permits the
  phase 7+ source-level modifications without redistribution friction.
- **2026-05-19** — chose **Option C** architecture (two emulators +
  LuaJIT broker). Reasons: real software runs day one; the dual-desktop
  model falls out of the architecture rather than being grafted on;
  native rewrites can happen per-subsystem without ever having a broken
  intermediate state.
- **2026-05-19** — added **issue 106** (GS/OS source toolchain) to phase
  1 after gabrilend confirmed OS-level modification is in scope. This is
  what elevates the project from "emulator on a handheld" to "modified
  OS running on a handheld."

## what each completed issue should produce

- **101** → `libs/gsplus/`, an aarch64 cross-toolchain, `docs/005-toolchain-setup.md`,
  the hardware-target "to confirm" section resolved.
- **102** → `build.sh`, `deploy.sh`, `patches/`, a working manifest emitter.
- **103** → GSplus patched to render to the RG DS panel framebuffer with
  2× integer scaling; ROM and boot disk wiring in place; GS/OS Finder
  visible on screen A.
- **104** → digitizer events wired into the IIgs's ADB mouse path;
  documented panel-to-IIgs coordinate mapping.
- **105** → broker command channel; runtime disk insertion / ejection;
  minimal bottom-panel picker UI.
- **106** → GS/OS source acquired and building from a 65C816 assembler
  toolchain; producing a bootable disk image that GSplus runs to the
  Finder.
- **120** → `issues/completed/demos/phase-1/run.sh`, `run-demo.sh` at
  project root, a screen recording, an updated TOC.
