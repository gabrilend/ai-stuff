# Clocks, resets, and timers

This document catalogues the chip's clock-gating, peripheral-
reset, and timing infrastructure. Every driver that touches a
peripheral needs to know which clock-gate register controls
its block, which soft-reset register can re-initialize the
block, and which timing source the driver can use for its own
delays and periodic work. Doing the harvest once, here, lets
every later driver reference a known authoritative catalogue
rather than re-deriving the same facts from the chip's
technical reference manual and the upstream Linux clock-driver
source.

The document and `docs/016-physical-memory-map.md` together
give a complete picture of what each peripheral block needs to
be brought up correctly — the memory-map document names *where*
each block lives, this document names *what each block needs*
in clocks, resets, and timing.

## The two clock-and-reset units

The chip has two Clock-and-Reset Unit (CRU) blocks, each
responsible for the clocks and resets in its part of the chip:

| Block    | Base          | Scope |
| -------- | ------------- | :---- |
| Main CRU | `0xFDD2_0000` | Most peripherals (USB, PWM1/2/3, eMMC, SD, display, etc.). |
| PMU CRU  | `0xFDD0_0000` | Peripherals in the chip's always-on power domain (the PMU GRF, GPIO0, PWM0, the PMU's own UART0 and I²C0, the USB-2 PHY reference clocks). |

**Base-address correction (confirmed against RK3568 TRM Part 1
Chapter 2):** the PMU CRU base is `0xFDD0_0000`, *not* `0xFDD4_0000`.
`0xFDD4_0000` is the I²C0 controller (the PMIC bus). An earlier
phase-1 register probe of `0xFDD4_0180` read all-zeros because it
was reading inside I²C0, not the PMU CRU. The PMU CRU's gate
registers (`PMUGATE_CON0..2`) begin at offset `0x180`
(`0xFDD0_0180`); its single soft-reset register
(`PMUSOFTRST_CON00`) is at `0x200`. Reading zeros there is normal:
a zero gate bit means the clock is *running*.

Both CRUs follow the same register-layout convention:

| Region              | Offset range  | Purpose |
| ------------------- | ------------- | :------ |
| `PLL_CON_xx`        | `0x000`-`0x0FF` | Phase-locked-loop configuration. The PLLs turn the chip's 24 MHz crystal into the various GHz-range clocks the CPUs and busses run on. Not normally touched by drivers — set by the bootloader. |
| `MODE_CON`          | `0x100`-`0x1FF` | Mode selection (PLL vs. crystal, etc.). Set by the bootloader. |
| `CLKSEL_CON_xx`     | `0x100`-`0x2FF` | Clock selection — for clocks with multiple possible source PLLs, the mux setting picks which PLL drives them. |
| `CLKGATE_CON_xx`    | `0x300`-`0x3FF` | Clock-gating. One bit per gated clock. Setting the bit gates the clock (off, saves power); clearing the bit ungates (on). Each register is write-mask encoded — the upper sixteen bits select which lower-sixteen bits the hardware actually changes, the lower sixteen bits carry the value. Indexing: `CLKGATE_CON(n)` is at offset `0x300 + n*4`. |
| `SOFTRST_CON_xx`    | `0x400`-`0x4FF` | Peripheral software reset. Asserting the bit puts the named hardware block back into its post-reset state; deasserting takes it back out. Same write-mask convention as the clock-gate registers. Indexing: `SOFTRST_CON(n)` at offset `0x400 + n*4`. |

The write-mask convention is the same chip-wide convention the
GRF blocks use. To set a specific bit `B` in a register `R`
without touching anything else, write `(1u << (B+16)) | (value
<< B)` to `R`.

## Clock identifiers and their register locations

The mainline Linux device tree references chip clocks by
numeric identifier (the values in
`include/dt-bindings/clock/rk3568-cru.h`). The IDs are
sequential — the chip has hundreds of clocks — and each ID
corresponds to a specific bit in a specific `CLKGATE_CON_n`
register. The mapping lives in
`drivers/clk/rockchip/clk-rk3568.c` in the upstream Linux tree.

The clocks our drivers (current and deferred) need to control:

| Clock name           | Clock ID | CRU register             | Bit | Note |
| -------------------- | -------- | ------------------------ | :-: | :--- |
| `ACLK_USB3OTG0`      | -        | `CLKGATE_CON(10)` = `0xFDD20328` | 8 | AXI clock to the USB 3.0 OTG controller — the controller's main register-access clock. |
| `CLK_USB3OTG0_REF`   | -        | `CLKGATE_CON(10)` = `0xFDD20328` | 9 | Reference clock for the USB 3.0 OTG controller. |
| `CLK_USB3OTG0_SUSPEND` | -      | `CLKGATE_CON(10)` = `0xFDD20328` | 10 | Suspend/low-power clock for the USB 3.0 OTG controller. |
| `CLK_USBPHY0_REF`    | 19       | PMU CRU mux              | -  | USB 2.0 PHY 0 reference clock, in the PMU CRU. Not a gate — a mux. By reset default sources from the 24 MHz crystal; no software action needed in phase 1. |
| `PCLK_PWM1`          | -        | `CLKGATE_CON(31)` = `0xFDD2037C` | 10 | APB bus clock for the PWM1 controller block (controller base `0xFE6E_0000`). Confirmed against TRM Part 1 Chapter 2. |
| `CLK_PWM1`           | -        | `CLKGATE_CON(31)` = `0xFDD2037C` | 11 | Functional clock for the PWM1 controller block. (PWM1 capture clock is bit 12.) |
| `PCLK_PWM2`/`CLK_PWM2` | -      | `CLKGATE_CON(31)` = `0xFDD2037C` | 13 / 14 | PWM2 controller block (base `0xFE6F_0000`). Capture clock is bit 15. |
| `PCLK_PWM3`/`CLK_PWM3` | -      | `CLKGATE_CON(32)` = `0xFDD20380` | 0 / 1 | PWM3 controller block (base `0xFE70_0000`). Capture clock is bit 2. |
| `PCLK_PWM0`/`CLK_PWM0` | -      | PMU `PMUGATE_CON(1)` = `0xFDD00184` | 6 / 7 | PWM0 lives in the PMU domain (controller base `0xFDD7_0000`), so its gates are in the *PMU* CRU, not the main CRU. Capture clock is bit 8. |
| `ACLK_EMMC`          | -        | `CLKGATE_CON(9)` = `0xFDD20324`  | 5  | AXI bus clock to the eMMC SDHCI controller at `0xFE31_0000`. Required before any controller register access. |
| `HCLK_EMMC`          | -        | `CLKGATE_CON(9)` = `0xFDD20324`  | 6  | AHB register-access clock for the eMMC controller. Required before any controller register read. |
| `BCLK_EMMC`          | -        | `CLKGATE_CON(9)` = `0xFDD20324`  | 7  | Block / internal core clock for the eMMC controller. Without this, controller register reads return garbage and writes silently drop. *The most commonly missed eMMC clock.* |
| `CCLK_EMMC`          | -        | `CLKGATE_CON(9)` = `0xFDD20324`  | 8  | Card-clock source for the eMMC's bus interface. Required before issuing CMD0. |
| `TCLK_EMMC`          | -        | `CLKGATE_CON(9)` = `0xFDD20324`  | 9  | Timer clock for the eMMC controller (24 MHz from `xin24m`). |
| `HCLK_SDMMC0`        | -        | `CLKGATE_CON(15)` = `0xFDD2033C` | 0  | AHB register-access clock for the microSD DW MSHC controller at `0xFE2B_0000`. |
| `CLK_SDMMC0`         | -        | `CLKGATE_CON(15)` = `0xFDD2033C` | 1  | Card-clock source for the microSD controller. Required before issuing CMD0. |

To ungate the three USB 3.0 OTG clocks together (the
phase-1-deferred USB clock work in issue 109a), one masked
write to `0xFDD20328`: `0x07000000` — mask bits 8, 9, 10 in
upper half, value bits zero in lower half (zero in a gate bit
means ungated).

### Clock-source selection (not just gating)

Ungating a clock is separate from choosing its *source* and
*rate*. For most peripherals the bootloader has already pointed
the source mux at a sensible PLL; on the SD-boot path it has
*not* for the blocks the bootloader never uses. The eMMC card
clock is the one that bit us:

| Clock | Mux register | Field | Reset default | What to set |
| ----- | ------------ | :---- | :------------ | :---------- |
| `CCLK_EMMC` | `CLKSEL_CON(28)` = `0xFDD20170` | bits 14:12 (`cclk_emmc_sel`) | `000` = 24 MHz (`xin_osc0`) | `001` = `clk_gpll_div_200m` (200 MHz) |
| `BCLK_EMMC` | `CLKSEL_CON(28)` = `0xFDD20170` | bits 9:8 (`bclk_emmc_sel`) | `00` = 200 MHz | leave at default |

The trap: the eMMC SDHCI controller's `CAPABILITIES` register
*advertises* a 200 MHz base clock (its `Base Clock Frequency For
SD Clock` field reads `0xC8` = 200). That value is a static
chip-integration constant, not a live readout of the mux. On the
SD-boot path the bootloader never programs `cclk_emmc_sel`, so it
sits at its 24 MHz reset default while the controller's divider
math assumes 200 MHz — the real card clock comes out ~8× too
slow. The eMMC driver sets `cclk_emmc_sel = 001` during CRU
bring-up so the advertised and actual base clocks agree. The full
source-mux option list for each clock is in TRM Part 1 Chapter 2;
the source mux for any other never-bootloader-touched block
should be checked the same way before trusting `CAPABILITIES`-style
advertised rates.

PWM source muxes (for 106c): `clk_pwm{1,2,3}_sel` live in
`CLKSEL_CON(72)` = `0xFDD20220` (bits 9:8 / 11:10 / 13:12), reset
`01` = 24 MHz crystal — fine for the LED PWM as-is.

## Resets and their register locations

The same identifier-to-register-and-bit pattern applies to the
`SOFTRST_CON_xx` registers. The resets our drivers (current
and deferred) need to assert or deassert:

| Reset name        | Reset ID | CRU register            | Bit | Note |
| ----------------- | -------- | ----------------------- | :-: | :--- |
| `SRST_WDT_NS`     | 138      | `SOFTRST_CON(8)` = `0xFDD20420` | 10 | The watchdog hardware block's reset. Asserting and then deasserting silences the watchdog (puts it back into its post-reset "disabled" state). The hardware otherwise cannot be disabled once it has been enabled. |
| `SRST_USB3OTG0`   | 148      | `SOFTRST_CON(9)` = `0xFDD20424` | 4 | The USB 3.0 OTG controller's reset. Asserted before configuring the controller, then deasserted as the last step before the controller comes online. |
| `SRST_A_EMMC`     | 117      | `SOFTRST_CON(7)` = `0xFDD2041C` | 5  | eMMC AXI clock domain reset. |
| `SRST_H_EMMC`     | 118      | `SOFTRST_CON(7)` = `0xFDD2041C` | 6  | eMMC AHB clock domain reset. |
| `SRST_B_EMMC`     | 119      | `SOFTRST_CON(7)` = `0xFDD2041C` | 7  | eMMC BCLK (block) domain reset. *The most commonly missed eMMC reset.* When this stays asserted, register reads succeed but writes silently drop. |
| `SRST_C_EMMC`     | 120      | `SOFTRST_CON(7)` = `0xFDD2041C` | 8  | eMMC CCLK (card clock) domain reset. |
| `SRST_T_EMMC`     | 121      | `SOFTRST_CON(7)` = `0xFDD2041C` | 9  | eMMC TCLK (timer clock) domain reset. |
| `SRST_H_SDMMC0`   | 211      | `SOFTRST_CON(13)` = `0xFDD20434`| 3  | microSD AHB clock domain reset. |
| `SRST_SDMMC0`     | 212      | `SOFTRST_CON(13)` = `0xFDD20434`| 4  | microSD controller reset. u-boot does *not* deassert this on the SD-boot path (the BootROM reads the boot chain blobs via fixed-offset reads, not through the SDMMC0 controller's protocol stack), so the kernel must pulse it before any register access. |
| `SRST_P_PWM1`/`SRST_PWM1` | - | `SOFTRST_CON(23)` = `0xFDD2045C`| 0 / 1 | PWM1 controller APB and functional resets (for 106c). |
| `SRST_P_PWM2`/`SRST_PWM2` | - | `SOFTRST_CON(23)` = `0xFDD2045C`| 2 / 3 | PWM2 controller resets. |
| `SRST_P_PWM3`/`SRST_PWM3` | - | `SOFTRST_CON(23)` = `0xFDD2045C`| 4 / 5 | PWM3 controller resets. |
| `SRST_P_PWM0`/`SRST_PWM0` | - | PMU `PMUSOFTRST_CON00` = `0xFDD00200` | 7 / 8 | PWM0 (PMU domain) APB and functional resets. |

Reset-identifier-to-register arithmetic: `SOFTRST_CON(n)` is at
offset `0x400 + n*4`, and reset ID `I` lives in
`SOFTRST_CON(I / 16)` at bit `I % 16`. So reset ID 138 →
register `8`, bit `10`; reset ID 148 → register `9`, bit `4`.

To assert a reset, write `(1u << (bit + 16)) | (1u << bit)` to
the register. To deassert, write `(1u << (bit + 16))` (mask
the bit, leave the value bit clear).

## The watchdog (DW_apb_wdt at `0xFE60_0000`)

Hardware safety timer. Counts down at a configured rate from a
configured initial value; when the count hits zero, it pulses
the chip's reset line and the system reboots. Software is
expected to periodically write a magic value to a specific
register before the count reaches zero — "pet the watchdog" —
to reset the counter. If the software hangs (a bug, a missed
interrupt, an infinite loop), the writes stop, the counter
reaches zero, the chip resets, the system has a chance to
recover. In a deployed product the watchdog is a safety net
that turns a fatal software bug into a transient reboot
instead of a dead device.

Cannot be disabled in software once enabled. The driver
comment in upstream Linux `drivers/watchdog/dw_wdt.c` is
explicit: writing zero to the enable bit is ignored. The only
ways to stop the watchdog are to pet it forever, or to put the
entire hardware block through a reset cycle via the `SRST_WDT_NS`
soft-reset in the main CRU (which is what the upstream Linux
driver does in its rare "stop the watchdog" path).

Register window:

| Offset | Name      | Purpose |
| :----: | :-------- | :------ |
| `0x00` | `WDT_CR`   | Control register. Bit 0 is the enable; writes to clear it are silently ignored once it has been set. |
| `0x04` | `WDT_TORR` | Timeout range. Lower bits select the timeout. BSP defaults are commonly small — around 2-3 seconds at the chip's typical watchdog-tclk frequency. |
| `0x08` | `WDT_CCVR` | Current count value (read-only). |
| `0x0c` | `WDT_CRR`  | Counter restart register. Writing the byte value `0x76` resets the counter to its top value (i.e., "pets" the watchdog). |
| `0x10` | `WDT_STAT` | Interrupt status. |
| `0x14` | `WDT_EOI`  | Interrupt clear. |

Phase-1 disposition (issue 103g): silence via the CRU reset
sequence at the top of `kernel_main`. The watchdog hardware
block goes back to its post-reset disabled state and stays
there for the rest of the kernel's lifetime.

Phase 2 or 3 disposition (issue 103g, deferred): silence is
replaced by an explicit re-enable plus a periodic petting task
scheduled by soramech. The watchdog becomes the safety net it
was designed to be — a kernel hang that prevents the
scheduler from reaching the pet task triggers an automatic
recovery reset.

## The ARM Generic Timer

Every aarch64 CPU has a built-in 64-bit counter and a
comparator pair, accessible through system registers (the
`mrs`/`msr` instruction family, no MMIO surface). All four
cores read the same monotonically-increasing counter value at
any given moment; the counter ticks at a fixed frequency that
the bootloader configures and exposes through `CNTFRQ_EL0`.
On this chip family the frequency is 24 MHz exactly — one
tick every 41 and two-thirds nanoseconds.

The relevant system registers (no MMIO addresses, accessed
through `mrs`/`msr`):

| Register      | Purpose |
| :------------ | :------ |
| `CNTFRQ_EL0`  | Counter frequency in Hz. Read-only at lower exception levels. Set once by the bootloader; on this chip family equals 24,000,000. |
| `CNTVCT_EL0`  | Virtual counter — current count value. Read with `mrs Xn, cntvct_el0`. The counter monotonically increases at the rate `CNTFRQ_EL0` hertz. |
| `CNTV_CTL_EL0` | Virtual timer control. Bit 0 enables the timer; bit 1 masks the interrupt; bit 2 indicates the comparator has been reached. |
| `CNTV_CVAL_EL0` | Virtual comparator value. When `CNTVCT_EL0` reaches this value, the timer fires its interrupt (if enabled and unmasked). |
| `CNTV_TVAL_EL0` | Relative-mode comparator. Writing a 32-bit signed value `N` sets `CNTV_CVAL_EL0` to the current `CNTVCT_EL0` plus `N`. Convenient for "fire in N ticks from now." |

The Generic Timer is the canonical periodic-interrupt source
for every aarch64 kernel — Linux uses it for scheduler ticks,
sleep timeouts, and time-of-day. It has no clock-gate or pinmux
to set up; every aarch64 chip exposes it from the moment the
CPU runs its first instruction.

Phase 2 will bring this up in soramech for scheduler ticks
(issue 209 territory) and for the watchdog petting task (issue
103g's phase-2 portion). No phase-1 issue currently needs the
Generic Timer.

## Dedicated hardware timer blocks

The chip exposes six independent hardware timer peripherals at
MMIO addresses, each a configurable down-counter with reload
and interrupt-on-zero. Used by Linux as a clocksource on
systems where the Generic Timer is busy; redundant for our
kernel given the Generic Timer covers the same role with no
peripheral bring-up cost.

| Base          | Block       | Notes |
| ------------- | :---------- | :---- |
| `0xFE5F_0000` | TIMER0      | Six timer channels, each independently configurable. |
| `0xFE5F_0020` | TIMER1      | (Same block, different channel base.) |
| ...           |             | (Channels 2-5 follow at +0x20 increments.) |

Not used in phase 1.

## PWM controllers as alternate timers

Every PWM channel on this chip is a configurable counter with
period and duty-cycle registers and an optional interrupt on
period rollover. A PWM channel not assigned to drive an output
pin can be configured as a plain interrupt-on-period timer.
The chip has sixteen PWM channels total (PWM0 through PWM15)
across four controller blocks; the three the LED layer needs
(PWM5/6/7) leave thirteen channels available as timers if
some part of the kernel ever wants more than the Generic Timer
can provide.

Same register window per channel as the LED-driving PWMs
(documented in `docs/016-physical-memory-map.md`): counter
register at +0, duty at +4, period at +8, control at +0xC.
Used as a timer, only the period register and the control
register's enable / continuous / interrupt bits are relevant.

Not used in phase 1.

## Real-Time Clock

The chip has a true RTC for wall-clock time, backed in the
deployed device by the same battery that powers the system
when it is "off." Counts in seconds, with finer subdivision
available through its registers. Useful for timestamping
debug log entries and for any clock-of-the-day need; not
useful for scheduler ticks (its granularity is too coarse).

Base address: looked up at the point a driver needs it; not
catalogued here because no current or near-future driver
needs it.

## Performance Monitoring Unit counters

Each CPU core has dedicated cycle and event counters with
overflow interrupts. Programmable as event counters for cache
misses, branch mispredictions, instructions retired, and so
on. Mostly used for profiling, not for periodic scheduling.

Not used in phase 1.
