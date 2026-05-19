---
name: boot configuration
phase: 5
status: pending
blockedBy: [220]
---

# 501 — boot configuration

The broker starts automatically when the device powers on, picks the
right boot disks for each instance, and reaches "both screens
running GS/OS" without user intervention.

## current behavior

Up through phase 2 demos, the broker is launched manually after
logging in to the device's Linux. The boot story is "ssh in, run
the broker by hand."

## intended behavior

- On power-on, the RG DS's Linux init starts the broker as a
  system service (systemd unit, OpenRC service, or sysvinit script —
  whichever the chosen Linux distro uses).
- The broker reads `~/.apple-IIds/config.lua` for its configuration:
  which ROM, which boot disk per instance, which shared volume
  location, screen mappings, sleep behavior, etc.
- The default config boots a known-good GS/OS image (the
  source-built one from issue 106 once it's ready, or a stock image
  before) on each screen.
- The user sees: power on → brief loading indicator (broker
  starting) → GS/OS Finder on both screens. No login prompt, no
  Linux terminal flash, no Anbernic launcher.
- If the broker fails to start (e.g., missing ROM, corrupt config),
  the user sees a friendly error message on screen A explaining
  what went wrong and how to fix it. Not a kernel panic; not a
  blank screen.

## suggested implementation steps

1. Decide the boot init system based on the chosen Linux distro
   (issue 101's resolution of "Linux distro on the RG DS" — stock
   vs replaced).
2. Write the service unit / startup script that launches the broker.
3. Write a `apple-IIds-boot.sh` wrapper that:
   - reads config
   - checks for required files (ROM, disks)
   - launches the broker with the right arguments
   - on broker exit, restarts (with backoff) or shows a graceful
     error
4. Suppress the Linux boot messages by configuring quiet boot in
   the kernel command line and disabling the default getty on the
   console.
5. Add a "first boot" path: if `~/.apple-IIds/config.lua` doesn't
   exist, generate a default one and proceed.
6. Test the cold-boot story end to end: power off the device,
   power it on, verify GS/OS appears on both screens in under N
   seconds.

## related documents

- `docs/001-architecture-overview.md` — broker is the only user-
  visible process
- `issues/101-source-and-toolchain.md` — Linux distro choice gates
  this issue's init-system decision

## known design questions

- Target cold-boot time? Aspirational: under 10 seconds from power-
  button to GS/OS Finder. Realistic for phase 5: under 30 seconds.
  Tightening this is a phase 11 (bare-metal) concern.
- How does the user get into the Linux shell if they need to (for
  debugging)? A boot-time button combo (e.g., holding L2 during
  power-on) drops into a developer console. Document this clearly
  but don't surface it in normal UI.
