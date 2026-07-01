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
- `018-emmc-host-controller.md` — what phase-1 hardware
  testing actually taught us about the eMMC host controller
  (dwcmshc): the slot's voltage support, base clock, pinmux
  layout, vendor-area register quirks, hardware-reset path,
  and a reference register dump from a working bring-up.
  Captures the empirical answers the upstream datasheet and
  Linux driver source either don't agree on or don't say
  cleanly.
- `019-board-pinmux.md` — every peripheral's pin assignment
  on the Anbernic RG DS, extracted from the device tree.
  One table per peripheral family (SDMMC, I²C, UART, PWM,
  audio, display, touch, gamepad, sensors). The GRF base
  addresses and bank-window offsets so any future bring-up
  knows exactly which IOMUX register to write.
- `020-sdmmc0-host-controller.md` — the SDMMC0 (microSD) DW
  MSHC controller. Sibling to 018: the CRU dependencies, the
  HCON discriminator, the FIFOTH value, the update-clock
  no-op CMD dance, the clock-divider math, and the polling-
  loop error bits the driver must check explicitly.
- `021-pmic-and-regulators.md` — the board's RK817 PMIC and
  every regulator rail it provides. Which rails are always-on
  vs. switchable, what they power, why phase 1 doesn't need
  to talk to the PMIC at all, and what the path looks like
  for when later work does (i2c0, address 0x20, voltage
  registers from the RK817 datasheet).
- `022-usb-device-controller.md` — DWC3 USB-3 OTG controller
  and the USB2 PHY GRF for device-mode bring-up (issues
  109a/b/c). Decodes the USB2 PHY `CON0` register (the OTG
  port is already out of suspend at reset — 109a doesn't need
  to clear a power-down bit), names the CRU clocks/reset and
  the PHY power-on reset, and points 109b's endpoint-command
  hang at TRM Part 2 Ch17.
- `023-display-controller.md` — VOP2 + MIPI DSI + MIPI TX
  DPHY reconnaissance for the display issues (111a-d, 112).
  Region maps, the minimum register path to scan one
  framebuffer to one panel, and the init-ordering constraints
  the TRM flags. Marks the gaps each 111x issue must still
  resolve.
- `024-emmc-partition-map.md` — the factory GPT layout of the
  internal eMMC, read off a real device once the eMMC bring-up
  worked. The 15 stock Android partitions with their LBAs and
  sizes (uboot, trust, boot, recovery, super, userdata, …),
  what the 16 MiB boot-chain backup captures, and what a full
  factory-restore image needs.
- `datasheets/INDEX.md` — catalogue of the chip and
  standards PDFs downloaded to `docs/datasheets/`: RK3568 TRM
  Parts 1 & 2, RK3568 brief datasheet, SDHCI v4.20 spec,
  JEDEC eMMC 5.1 spec, Synopsys DWC_mshc excerpt. Includes a
  "which doc to read for which symptom" table.
