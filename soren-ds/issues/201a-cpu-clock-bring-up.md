# 201a — Run the CPU at its rated speed

## Current behavior

The kernel runs at the CPU clock speed the bootloader left
behind. On the SD-card boot path through ROCKNIX's u-boot,
that turns out to be roughly fifty megahertz — comfortably
two orders of magnitude below the chip's rated full speed of
1.8 gigahertz. The mainline-derived bootloader configures
its CPU phase-locked loop for a moderate speed that's
sufficient for its own work (DRAM init, reading the kernel
image off the SD card, the small amount of register
configuration u-boot needs to do) and does not ramp up
before handing off. Our kernel inherits whatever the
bootloader left running.

This shows up most visibly during the eMMC-to-microSD backup
in phase 1, which is purely CPU-bound (no DMA) and takes
many minutes per ten-megabyte chunk at the inherited clock.
The rest of the kernel's work runs at human-noticeable but
acceptable speeds — LED transitions feel a tick slower than
expected, the watchdog-petting cadence comes out a hundredth
of its commented value, every busy-wait constant is
calibrated for the slow clock rather than for the rated
speed.

**Update (2026-06-30) — the `cpu-clock-recon` probe corrects the
premise.** The ~50 MHz figure above was a guess, and it is wrong. The
ARM PLL (APLL) is configured and *locked* at ~816 MHz in normal
(PLL-driven) mode, and the core clock mux/divider reads pass-through, so
the cores are very likely already near 816 MHz. The peripheral PLLs
decode to their standard values (GPLL 1200, CPLL 1000, NPLL 1200 MHz),
which confirms the register read is sound. So the ~35x slowness is NOT
the clock — it is almost certainly the CACHES being off: the MMU is
disabled in phase 1, and with no instruction cache every fetch stalls on
DRAM, making an 816 MHz core behave like a ~50 MHz one. The real giant
lever is the cache/MMU bring-up; the APLL bump from 816 MHz to 1.8 GHz is
a secondary ~2.2x on top, and it pairs with a core-voltage raise on the
RK817 (DVFS — a faster clock needs more volts). This issue's clock-bump
scope stands, but it is no longer the headline; confirm the actual core
frequency (a cycle-counter measurement) before assuming the 816 MHz read
is the delivered clock and not just the PLL setting.

## Intended behavior

The kernel writes to the chip's main clock-and-reset unit
(CRU) configuration registers to set the CPU phase-locked
loop's multiplier to its rated maximum, waits for the PLL to
indicate lock, and switches the CPU's clock multiplexer to
take its source from the now-stable PLL output. After this
runs, the CPU core executes at 1.8 gigahertz — roughly thirty
to forty times faster than the inherited bootloader clock.
Every busy-wait constant in the kernel scales accordingly:
the LED hello-flash constant goes from seven million back
toward something closer to three hundred million, the
watchdog timeout becomes a comfortable margin instead of a
close-run thing, and the eMMC-to-microSD backup finishes in
a small number of minutes instead of hours.

## Why this is phase 2 rather than phase 1

Nothing in phase 1's roadmap strictly requires the CPU to be
at its rated speed. The slow backup is the only visible
practical cost; every other phase-1 feature works correctly
at the inherited bootloader clock, just slowly. Phase 2 — the
soramech runtime bring-up — is where the speed actually
starts to matter. The threading system's scheduler, the
multi-core bring-up (the work that 202 describes),
and any application code that runs on top of soramech all
benefit hugely from running at full speed. Folding the CPU
clock bring-up into the pre-bring-up setup means the multi-
core work happens at the right clock from the first
instruction, rather than having to recalibrate constants
midway through.

## Implementation steps

1. Identify the CRU's CPU PLL ("APLL") configuration register
   offsets and the multiplier / divider encoding from the
   chip's TRM and the upstream Linux Rockchip CRU driver
   (`drivers/clk/rockchip/clk-rk3568.c`, the `rk3568_pll_clks`
   table). The CRU base is `0xFDD2_0000` (per
   `docs/016-physical-memory-map.md`).
2. Write the target multiplier and dividers to the APLL
   configuration registers. Standard pattern: put the PLL into
   slow-mode (sourced from the 24 MHz crystal directly,
   bypassing the PLL output), reprogram, wait for the lock bit
   to go high, then switch back to normal mode.
3. Switch the CPU's clock source multiplexer to take its
   source from the reprogrammed APLL. (Same CRU register set;
   the specific clock-source-select register depends on the
   chip's PLL routing topology.)
4. Recalibrate all the kernel's busy-wait constants for the
   new clock speed. The LED hello-flash constant, the
   watchdog-petting interval inside the busy-wait utility,
   the rough-delay constants in the USB-controller bring-up,
   the heartbeat cadence in the eMMC-to-SD backup — every
   busy-wait gets multiplied roughly by the speedup ratio,
   with a comment naming the original slow-clock value so a
   future reader can scale back if the clock changes again.
5. Verify on hardware. The LED-hello flash should now look
   like a quick blink rather than a held flash; the
   eMMC-to-microSD backup should finish in a small number of
   minutes; busy-waits that took perceptible time before
   should now be imperceptible.

## What this issue does not do

- *Configure any other PLL.* The chip has separate PLLs for
  DRAM, peripheral busses, GPU, video subsystems, and so on.
  The bootloader has already set those to sensible values
  for their own purposes; this issue only touches the CPU
  PLL. Other PLLs come up if and when a specific subsystem
  needs them re-configured.
- *Implement dynamic frequency scaling.* The clock change
  this issue performs is one-shot at boot. Power-saving
  scaled-down operation, thermal-throttling adjustments, or
  any other runtime clock changes are a much larger piece
  of work (DVFS — dynamic voltage and frequency scaling)
  and not in scope here.
- *Bring up the secondary cores.* That work lives in 202;
  this sub-issue makes the first instruction each core
  executes run at the right speed but does not itself touch
  cores 1-3.
- *Turn the caches on.* That is 201, and the recon note
  above concluded it is the larger of the two levers by far.
  This one is the clock only.

## Related documents

- `docs/016-physical-memory-map.md` — main CRU base address.
- `docs/017-clocks-and-timers.md` — the CRU register layout
  and the broader catalogue of clocking infrastructure.
- `issues/201-the-memory-map-that-turns-the-caches-on.md` —
  the cache half of the same problem, and the parent this
  sub-issue now hangs from.

## Blocked by

Nothing. Phase 1 closing is not a hard dependency; the issue
can land as the first phase-2 work.

## Blocks

The multi-core bring-up (202) — for the multi-core work to be
useful, the cores need to be at full speed. Anything that
depends on the engine's scheduling running fast also blocks
on this.

## Parent

201 — the caches. The phase-2 renumbering moved the parent
from the multi-core bring-up to the cache bring-up, which is
where this issue's own recon note said the real story was.
