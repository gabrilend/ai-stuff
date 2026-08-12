# 103g — Watchdog handling

## Current behavior

The chip's watchdog hardware block (a DesignWare DW_apb_wdt at
MMIO base `0xFE60_0000`) is silenced as the very first thing
`kernel_main` does, before any other initialization. The
silencing is achieved by asserting and then deasserting the
watchdog's soft-reset bit in the chip's main clock-and-reset
unit — two MMIO writes to `0xFDD2_0420`, the first to put the
watchdog hardware block back into its post-reset disabled
state and the second to release the reset so the block sits
quietly with its enable bit cleared. After these two writes
the watchdog's countdown is not ticking and the chip will not
reset itself regardless of what the kernel does.

This is the phase-1 disposition. The watchdog is not used as a
safety net during phase 1 because phase 1 is bring-up: the
kernel hangs frequently during development, and a watchdog
that resets the chip every few seconds prevents the developer
from observing the hang. Silencing the watchdog gives the
developer unlimited time to inspect the LEDs, the debug log,
and (eventually) the CDC-ACM serial channel without losing
state to a reboot.

The hardware block stays accessible — its register window
still reads back its post-reset values — but its enable bit is
clear and its countdown is not running.

## Why the watchdog needed handling at all

Hardware testing during the SD-card boot path found the chip
resetting itself every few seconds during early `kernel_main`
execution. The reset was not caused by anything the kernel
did; it was the watchdog hardware block, enabled inside the
Rockchip BSP boot blobs (the DDR-init trust-firmware that runs
before u-boot proper) and left ticking through the u-boot
handoff to our kernel. The BSP enables the watchdog as a
safety net against bring-up hangs in its own code; the
mainline u-boot the BSP launches into does not explicitly
disable the watchdog before booti (the upstream Linux kernel
takes over feeding the watchdog through its own subsystem
once the dw_wdt driver probes, several seconds into boot).

Our kernel has no equivalent feeding mechanism in phase 1, so
the watchdog's BSP-default timeout (around two and a half
seconds) was firing before the kernel could complete its
allocator self-test and its USB controller bring-up. The
silencing in this issue stops the resets and lets the rest of
phase 1 proceed.

## The phase-2-or-3 disposition

The phase-1 silence is the wrong long-term answer. A shipping
product should use the watchdog as the safety net it was
designed to be: a kernel hang that prevents the scheduler
from doing useful work for too long should reset the device
and let it try again. That requires a mechanism we do not
have yet — periodic task scheduling — which lands as part of
the soramech runtime in phase 2 or 3.

When the periodic task mechanism is in place, the silence in
this issue gets reversed: the watchdog is brought back online
(its enable bit is set, its timeout register is configured to
something reasonable like one second), and a low-priority
soramech task is registered to pet it every few hundred
milliseconds. The pet is a single byte-value write to the
watchdog's counter-restart register at offset `0x0C` from its
base (the magic value `0x76` to register `WDT_CRR`). If the
scheduler reaches the pet task on schedule, the watchdog's
countdown resets and the device keeps running; if the
scheduler hangs, the pet does not happen, the countdown hits
zero, the chip resets, the kernel boots again.

The periodic task mechanism uses the ARM Generic Timer (see
`docs/017-clocks-and-timers.md` for the Generic Timer's
interface). The same mechanism is also what soramech uses for
its scheduler ticks. The watchdog petting task is the first
useful application of the mechanism and exercises it in a way
that is observable from outside — if the petting task stops,
the chip resets, and any developer can see that the soramech
runtime has frozen.

## What this issue does not do

- *Decide whether the watchdog stays online during development
  too.* The petting-task disposition is for shipping
  products. Development builds might prefer to keep the
  watchdog silenced (so a debugger can sit in the kernel
  indefinitely). The flag, build option, or runtime switch
  that picks between dispositions is a phase-2-or-3 design
  decision and lives in the soramech-side portion of this
  issue.
- *Implement the periodic task mechanism.* The mechanism is a
  soramech-runtime concern — its design includes scheduler
  integration, prioritization, the Generic Timer interrupt
  path, and the wake-from-WFE machinery in 206. This issue's
  phase-2 portion uses the mechanism but does not provide it.
- *Replace the watchdog with a software equivalent.* The
  watchdog hardware works fine; nothing about its silicon
  needs reinventing. The handling story is "leave the
  hardware alone, feed it from the right place at the right
  time."

## Implementation steps

### Phase 1: silence

1. At the very top of `kernel_main`, before `led_init` and
   everything that follows, write the watchdog's soft-reset
   assert value to the main CRU's `SOFTRST_CON(8)` register
   at `0xFDD2_0420`. The write-mask convention says: to set
   bit 10 (the `SRST_WDT_NS` bit), the value is
   `(1u << 26) | (1u << 10) = 0x04000400`.
2. Write the deassert value to the same register:
   `(1u << 26) | (0u << 10) = 0x04000000`. The watchdog
   hardware block is now in its post-reset state — enable
   bit clear, countdown not running.
3. Confirm by hardware test: the kernel sits in `kernel_main`
   for longer than the BSP watchdog timeout (a few seconds)
   without resetting. The "two amber, dark, green flash"
   cycling pattern from the symptom that prompted this issue
   stops; the LEDs hold the most recent stage signal
   indefinitely.

The phase-1 portion of this issue is *code complete* when
those two writes are in `kernel_main` and the cycling pattern
stops on hardware. The issue stays open through phase 2 or 3
for the petting-task portion below.

### Phase 2 or 3: petting via soramech

4. When the soramech runtime gains periodic task scheduling
   (a new soramech sub-issue, to be created when phase 2 or
   3 starts and the scope is informed by soramech's actual
   shape), the petting task can land.
5. Remove the soft-reset-assert-and-deassert from the top of
   `kernel_main`; the watchdog now stays online from boot.
   Add a small post-soramech-init routine that enables the
   watchdog by writing to `WDT_CR` (the control register at
   offset `0x00`) and configures the timeout in `WDT_TORR`
   (offset `0x04`) for something reasonable — one second or
   so, chosen against the soramech scheduler's worst-case
   latency budget.
6. Register a low-priority soramech task that writes the byte
   value `0x76` to `WDT_CRR` at offset `0x0C` (so MMIO
   address `0xFE60_000C`) every few hundred milliseconds.
   The task's interval should be comfortably under the
   timeout — half the timeout is a common heuristic.
7. Verify on hardware: with the pet task running, the device
   stays up indefinitely; with the pet task deliberately
   disabled (a debug stub that returns without writing), the
   device resets at the configured timeout.

## Related documents

- `docs/017-clocks-and-timers.md` — the broader catalogue of
  the chip's clocking, reset, and timing infrastructure. The
  watchdog hardware block, its register window, and its
  soft-reset address all live in there alongside the related
  clock-and-reset register layout.
- `docs/016-physical-memory-map.md` — the watchdog's base
  address as part of the chip's peripheral register catalogue.

## Blocked by

The phase-1 portion of this issue is unblocked and can land
as soon as the two writes are added to `kernel_main`.

The phase-2-or-3 portion is blocked by the soramech runtime
having a periodic-task scheduling mechanism. The specific
sub-issue that brings that mechanism up does not exist yet;
its scope will be defined when soramech's broader bring-up
(issues 201-215) starts.

## Closes when

The phase-2-or-3 petting task is in place. The phase-1 work
unblocks the rest of phase 1's hardware bring-up but does not
close this issue; the safety-net story is the closing
condition.

## Parent

103.
