# Soren DS — documentation table of contents

The vision document lives at `notes/vision/000-vision.md`.

Other notes:

- `notes/safety/000-bricking-and-recovery.md` — every way the
  device could be made unrecoverable during development, why each
  scenario happens, and the design rule that prevents it. Read
  before any low-level flashing work.
- `notes/3c-model` — the original artistic seed for the modeller
  app. The formal spec grown out of it lives at
  `docs/010-modeller.md`.

## Reading order

Each doc assumes the previous ones. Read top to bottom for a full
tour; jump in by topic if you already know where you're going.

- `001-architecture-overview.md` — the system at a glance.
- `002-roadmap.md` — ten phases, lowest layer first. Nine for the
  launch system, one more for the first post-launch app.
- `003-threading-model.md` — task firing, ring buffers, atomics,
  memory ordering on ARM.
- `004-input-model.md` — touch screens, buttons, handedness,
  radial menu, drawers, inter-app links.
- `005-display-and-compositor.md` — two framebuffers, per-screen
  surfaces, damage tracking, drawer overlays, link transitions.
- `006-transport-and-networking.md` — USB-C, ad-hoc radio, rmail,
  peer-based addressing.
- `007-memory-model.md` — graduated path from flat memory to
  memory protection.
- `008-apps-overview.md` — the four launch apps, what they share,
  and the links between them.
- `009-deferred-work.md` — what we explicitly chose not to build,
  and why.
- `010-modeller.md` — the first post-launch app, sketched now so
  the platform can be designed to host it.
- `011-filesystem.md` — what the SD card hardware demands, what
  the launch system pointedly does not need from it, and the
  five box kinds that expose paths to apps.
- `012-soramech-runtime.md` — which pieces of soramech proper
  the launch system keeps, which it cuts, and how boxes get
  statically linked into the kernel image instead of dynamically
  loaded from disk.
- `013-background-app-lifecycle.md` — the foreground, background,
  and asleep states, the per-app work queue, and the
  always-on-input-box suppression mechanism that makes
  foreground/background a single-bit distinction.
- `014-hardware-overview.md` — the Anbernic RG DS chip by chip,
  the install path SoreOS commits to (SD-boot, then eMMC takeover,
  then USB-C as daily loop), and the known unknowns the device
  tree will fill in later.
- `015-led-diagnostic-codes.md` — what the three indicator LEDs
  on the front edge of the device mean at every kernel state.
  The first observable signal we have for "where did the kernel
  get stuck."
- `016-physical-memory-map.md` — the chip's full physical
  address space, harvested once so every later driver can
  reference one authoritative catalogue. DRAM extent and
  reservations on top; every peripheral register window
  below.
- `017-clocks-and-timers.md` — the chip's clock-gating,
  peripheral-reset, and timing infrastructure. Where each
  peripheral block's clock-gate bit lives in the CRU, which
  soft-reset register controls each block, what the
  watchdog hardware actually does, and which built-in
  timing sources the kernel can use for periodic work
  (the ARM Generic Timer, the dedicated hardware timer
  blocks, the PWM controllers reconfigured as timers, the
  RTC, the per-core performance counters).
