# Soren DS — eMMC host controller (dwcmshc) bring-up notes

The internal eMMC is owned by the RK3568's dwcmshc — a Synopsys
SD Host Controller (SDHCI-compatible base register set plus a
Rockchip vendor-area extension). This document is the
authoritative bring-up reference: it merges what phase-1 hardware
testing observed (the diagnostic dumps from
`src/018-bringup-test-suite.c`) with the register definitions
from the **RK3568 TRM Part 2, Chapter 7** (PDF in
`docs/datasheets/`). Where an earlier version of this doc
recorded a guess, the TRM-confirmed fact has replaced it.

Base address: `0xFE31_0000` (see `docs/016-physical-memory-map.md`).

## RESOLVED — the controller ignores the SDHCI clock divider

**Root cause (verified on hardware):** the rk3568 dwcmshc does
**not** honour the SDHCI internal clock divider. The card clock is
whatever `CCLK_EMMC` is set to, full stop. For many flash
iterations the driver ran `CCLK_EMMC` at 200 MHz and set the
SDHCI divider to ~0xFF expecting ~390 kHz at the card — but the
divider does nothing, so the card was actually clocked at
**200 MHz**, far beyond the ~400 kHz identification limit, and
never responded. Every register being "correct" was a red herring
because the one thing that mattered — the actual card clock — was
~530× too fast.

**The fix:** drive `CCLK_EMMC` itself at the target rate via the
CRU source mux (`CLKSEL_CON28`, bits 14:12), and leave the SDHCI
divider at pass-through (0):
- Identification: `cclk_emmc_sel = 0x5` (`clk_osc0_div_375k`,
  375 kHz).
- Transfer (legacy mode, no CMD6): `cclk_emmc_sel = 0x0`
  (`xin_osc0`, 24 MHz — inside the 26 MHz legacy ceiling).

This matches u-boot's `rockchip_sdhci.c`, which sets the card
clock with `clk_set_rate` on this same clock rather than the
SDHCI divider. With the fix the card answers immediately:
`CID[0]` reads a real value (`0x00010AA9` on the test unit, not
`0xFFFFFFFF`), `emmc_init` passes, and `emmc_read_block(0)`
returns real data.

Everything below this section is the investigation history that
led here — kept because the dead ends (and the confirmations of
what was *not* the cause) are themselves useful reference.

## The "card is silent" failure — investigation history

For many flash iterations the eMMC bring-up has failed the same
way: CMD0/CMD1/CMD2 report completion at the controller, but the
response registers all read the floating-bus pattern
`0xFFFFFFFF`, and CMD3 (the first command with an index check)
times out. Diagnostic dumps have since confirmed that **every
controller-side register is correctly configured** — pinmux
(function 1), pull-up, drive strength (level 2), input-enable,
the five CRU clocks + the 200 MHz `CCLK_EMMC` source mux,
`POWER_CONTROL` (3.0 V on), `CLOCK_CONTROL` (`0xFF07`, stable),
`HOST_CONTROL_1` (card-detect test), `INT_ENABLE`, `HOST_CTRL3`
(conflict-check off, clock-gating off), `EMMC_CONTROL`
(`CARD_IS_EMMC` set, card not held in reset). And yet the card
does not answer.

### Hypotheses tried and ruled out

- **RX clock inversion (`EMMC_DLL_RXCLK` bit 29).** The TRM says
  this bit "should be set to 1 for normal operation," which looked
  like the answer. A flash that confirmed the no-inverter bit
  applied (`DLL_RXCLK = 0x20000000` in the dump) **did not** fix
  the symptom. Upstream Linux's rk3568 low-speed path in fact
  writes `DLL_RXCLK = 0` (inverted) and works — the TRM note
  applies to the high-speed DLL-active path, not the
  identification clock. So the driver now writes 0 here to match
  upstream. *Not the cause.*
- **3.0 V vs 3.3 V slot voltage.** A real, necessary fix (see
  below), but on its own it did not make the card respond.
- **Drive strength / input-enable register confusion.** A real
  self-inflicted bug (we wrote drive-strength patterns into the
  input-enable registers), now fixed — but the symptom predated
  that bug, so fixing it did not resolve the silence either.

### Current hypothesis — card-state / hardware reset

With controller configuration exhausted, the remaining
explanation is the card's own state. On the SD-boot path the
eMMC is never reset by anything: its VCC is a hardwired always-on
rail (so it cannot be power-cycled in software), and it keeps
whatever state the BootROM's probe or a prior boot left it in.
The one card-level reset available is the dwcmshc's `EMMC_RST_N`
output (`EMMC_EMMC_CTRL` bit 2), which drives the card's RST_n
pin. The driver **pulses it low→high** (spec-mandated >1 µs
assert, >200 µs recovery) before CMD0. **Result: no change** —
the pulse executed (confirmed by readback) and the card stayed
silent. So card-state is ruled out too.

The I/O-domain voltage was also checked and ruled out: the
eMMC/flash pins sit in the `vccio2` domain, which on RK3568 is
**not** software-configured (it's absent from the device tree's
`io-domains` node) — its voltage is strapped by the
`FLASH_VOLSEL` pin (GPIO0_A7) in hardware, not by a register we
could have wrong.

### The actual fix — DLL bypass+start (from u-boot ground truth)

After register configuration, card-reset, and I/O-domain were all
ruled out, the answer came from reading the **working** driver:
u-boot's `drivers/mmc/rockchip_sdhci.c` (fetched to
`tmp/uboot-ref/`), which probes this exact eMMC successfully. Its
rk3568 `config_dll` for card clocks **below 100 MHz** (our
identification case) does NOT leave the DLL registers at zero —
it writes:

| Register | Value | Constituent bits |
|----------|-------|------------------|
| `DLL_CTRL` (0x800) | `0x01000001` | `BYPASS` (bit 24) \| `START` (bit 0) |
| `DLL_RXCLK` (0x804) | `0x80000000` | `RXCLK_ORI_GATE` (bit 31) |
| `DLL_TXCLK` (0x808) | `0x00000000` | — |
| `DLL_STRBIN` (0x80C) | `0x0C100000` | `DLYENA` (27) \| `DELAY_NUM_SEL` (26) \| `0x10 << 16` |

The u-boot comment is explicit: *"the bypass bit and start bit
need to be set if DLL is not locked."* At the identification
clock the DLL cannot lock, and without BYPASS+START the dwcmshc
does not generate valid sample/drive clocks — so the card never
sees a usable clock and never answers. **We had been writing all
four DLL registers to 0** through every prior iteration, which is
precisely the broken state. `src/012-emmc.c` now writes the
u-boot low-speed values in `dwcmshc_vendor_config`.

Two notes: (1) `DLL_RXCLK` bit 31 (`ORI_GATE`) is marked
"reserved" in the TRM register table, but the working driver
writes it — the reference driver is ground truth over the doc.
(2) This is why the earlier RX-clock-inversion lead (bit 29) was
a dead end: the relevant RX bit at low speed is bit 31, and the
real prerequisite is the DLL_CTRL bypass+start that we were
missing entirely.

This fix is implemented and pending its first flash. If it works,
the long silent-card saga closes here.

### If it still fails

The remaining explanation would be physical/board-level (clock or
commands not reaching the card pads — a level shifter, an enable,
or a depopulated part) — not diagnosable without test equipment.
But note the eMMC has never blocked anything else: SoreOS boots
and runs from the SD card, so eMMC bring-up can be deferred
regardless.

## The dwcmshc register map (what we actually touch)

Standard SDHCI registers (offsets `0x00`-`0xFF`) follow the SDHCI
spec (`docs/datasheets/sdhci-host-controller-spec.pdf`). The
Rockchip vendor-area registers (confirmed in TRM Part 2 Ch7):

| Offset | Name | Width | Reset | Purpose |
|--------|------|-------|-------|---------|
| `0x500` | `EMMC_VER_ID` | W | — | host version id |
| `0x508` | `EMMC_HOST_CTRL3` | **byte** | `0x01` | cmd-conflict-check enable (bit 0) |
| `0x52C` | `EMMC_EMMC_CTRL` | half | `0x0C` | eMMC control (see below) |
| `0x52E` | `EMMC_BOOT_CTRL` | half | `0x00` | boot-mode ack |
| `0x800` | `EMMC_DLL_CTRL` | word | `0x00` | DLL global control |
| `0x804` | `EMMC_DLL_RXCLK` | word | `0x00` | **RX clock — bit 29 must be set** |
| `0x808` | `EMMC_DLL_TXCLK` | word | `0x00` | TX clock phase |
| `0x80C` | `EMMC_DLL_STRBIN` | word | `0x00` | data-strobe phase (HS400) |
| `0x840` | `EMMC_DLL_STATUS0` | word | `0x00` | DLL lock status |

### `EMMC_EMMC_CTRL` (0x52C) bit decode — reset `0x0C`

| Bit | Name | Reset | Meaning |
|-----|------|-------|---------|
| 0 | `CARD_IS_EMMC` | 0 | 1 = device is eMMC (we must set this) |
| 1 | `DISABLE_DATA_CRC_CHK` | 0 | bus-test only; leave 0 |
| 2 | `EMMC_RST_N` | **1** | card hardware-reset output; **1 = reset deasserted (card running)** |
| 3 | `EMMC_RST_N_OE` | 1 | reset-pin output enable |
| 8 | `ENH_STROBE_ENABLE` | 0 | HS400 enhanced strobe |

**Correction to an earlier theory:** a previous version of this
doc and the driver guessed the card hardware-reset was "bit 12 of
EMMC_CONTROL" and tried pulsing it. That was wrong — bit 12 is a
CQE prefetch field. The real card-reset control is **bit 2**, and
its reset value is **1 (card NOT held in reset)**. So the
floating-bus symptom was never a card-reset problem; it was the
RX clock inversion above. We set `CARD_IS_EMMC` and otherwise
leave `EMMC_EMMC_CTRL` at its reset default (the card stays out
of reset). The board's device tree has no `reset-gpios` for the
eMMC — the RST_N line is driven by the controller through
GPIO1_C7, not a software GPIO.

### Vendor-area access width matters

`EMMC_HOST_CTRL3` (`0x508`) is a single byte inside a 32-bit
word. A 32-bit write clobbers neighbour bytes (the dump showed
`HOST_CTRL3 = 0x000F0001` after a word write of 0). Use a
**byte-width** write. General rule: write each vendor register at
its natural width (the table above lists each).

## Clocks and the 200-MHz-vs-24-MHz trap

The five eMMC clocks and five resets, and the **card-clock source
mux**, are catalogued in `docs/017-clocks-and-timers.md`. The
trap worth repeating here:

`CAPABILITIES` bits 15:8 = `0xC8` = **advertised** 200 MHz base
clock. That is a static chip-integration constant. But the actual
`CCLK_EMMC` source mux (`CLKSEL_CON28`, `0xFDD20170`, bits 14:12)
sits at its **24 MHz reset default** on the SD-boot path because
the bootloader never programs it. The SDHCI divider math assumes
the advertised 200 MHz, so without setting the mux the real card
clock is ~8× too slow. `src/012-emmc.c` sets `cclk_emmc_sel = 001`
(200 MHz) during CRU bring-up so the two agree.

With base = 200 MHz, the SDHCI divisor formula
`card_clock = base / (2 * divisor)` gives `0xFF` (255) → 392 kHz
for the identification phase (inside the eMMC 100-400 kHz range).

## Speed modes and the DLL (phase 1 vs. later)

The DLL configuration is tied to the card clock, and getting it
wrong is what kept the card silent. There are two regimes, drawn
straight from u-boot's `config_dll` (the working reference):

| Regime | Card clock | DLL config | Notes |
|--------|-----------|------------|-------|
| **Low speed** (phase 1) | < 100 MHz | `DLL_CTRL = BYPASS\|START` (`0x01000001`), `DLL_RXCLK = ORI_GATE` (`0x80000000`), `DLL_STRBIN = 0x0C100000` | DLL cannot lock at low clocks; it must be bypassed-but-started or no sample/drive clock is produced. |
| **High speed** (future) | ≥ 100 MHz | DLL reset → program `START_POINT`/`INC` → start → poll `DLL_STATUS0` for lock → set RXCLK/TXCLK/STRBIN tap values from the lock value | Needs a CMD6 switch into HS200/HS400, 1.8 V signaling, and a tuning pass. |

Phase 1 stays entirely in the low-speed regime:

- **Identification**: 392 kHz (divisor `0xFF`), DLL bypass.
- **Transfer**: 25 MHz (divisor `0x04`), DLL bypass. We do **not**
  issue CMD6, so the card stays in backward-compatible (legacy)
  mode, which tops out at 26 MHz — 25 MHz is the safe target.
  Anything ≥ 100 MHz would need the high-speed DLL-lock path and a
  CMD6 switch.

The high-speed regime is what a later issue brings up for the
fast eMMC backup (with DMA instead of PIO). The full register
sequence — DLL lock, tap-value math, the HS200/HS400 CMD6 switch,
the tuning loop — is in u-boot's `rockchip_sdhci.c`
(`rk3568_sdhci_config_dll` for the `clock >= 100 * MHz` branch,
plus `rockchip_sdhci_execute_tuning`). That driver is the
ground-truth reference; the TRM register tables alone proved
insufficient (they even mislabel the RXCLK `ORI_GATE` bit as
reserved).

## Slot voltage — 3.0 V, not 3.3 V

The slot does not support 3.3 V on this board. `CAPABILITIES`
(`0x226DC881`) voltage bits: bit 24 (3.3 V) = 0, bit 25 (3.0 V) =
1, bit 26 (1.8 V) = 0. Writing the Power Control voltage field to
3.3 V leaves the slot unpowered; write 3.0 V:
`POWER_CONTROL = (6 << 1) | 1 = 0x0D`. (This was a real, necessary
fix, but on its own it did not make the card respond — the RX
clock inversion was the remaining blocker.)

## Pinmux, pull, drive strength — and the input-enable trap

eMMC pins are all in GPIO1 banks B/C on function 1 (TRM Part 2
§7.5.1 confirms exactly this table):

| Signal | Pin | IOMUX register |
|--------|-----|----------------|
| D0-D3 | GPIO1_B4-B7 | `GRF_GPIO1B_IOMUX_H` (`0xFDC6000C`) |
| D4-D7 | GPIO1_C0-C3 | `GRF_GPIO1C_IOMUX_L` (`0xFDC60010`) |
| CMD/CLK/DS/RSTn | GPIO1_C4-C7 | `GRF_GPIO1C_IOMUX_H` (`0xFDC60014`) |

The bootloader does not set the eMMC pinmux on the SD-boot path,
so the kernel must. Pull-up is already applied by the BootROM;
drive strength resets to level 3 (adequate). **Do not write
`0xC4`/`0xC8` thinking they are drive-strength — they are the pad
input-enable registers** (`GRF_GPIO1x_IE`); clobbering them
disables the pins' input buffers and is a second way to get the
floating-bus symptom. The real drive-strength block starts at
`0x200`. Full layout in `docs/019-board-pinmux.md`.

## Bring-up order (as implemented in `src/012-emmc.c`)

1. Pinmux (function 1 on the eMMC pins).
2. Pad config: confirm pull-up; leave drive strength and
   input-enable at reset.
3. CRU bring-up: ungate the 5 clocks, set `cclk_emmc_sel` to
   200 MHz, pulse the 5 resets, read `CAPABILITIES` as a
   reachability discriminator.
4. SDHCI software reset (`RESET_ALL` → `0x2F`).
5. `dwcmshc_vendor_config` (after the reset): `HOST_CTRL3`=0
   byte-write, all four DLL registers = 0 (upstream low-speed
   values), `CARD_IS_EMMC` set, then an **`EMMC_RST_N` hardware-
   reset pulse** (assert >1 µs, deassert, recover >200 µs).
6. Post-reset SDHCI state: `INT_ENABLE`=all, `HOST_CONTROL_1`=0xC0
   (card-detect test level), `TIMEOUT`=0x0E, power-cycle the slot
   to 3.0 V.
7. Set the identification clock (divisor `0xFF` → ~392 kHz).
8. JEDEC card init: CMD0 (+ pre-idle), CMD1, CMD2, CMD3, CMD9,
   CMD7.

## Diagnostic snapshot — phase-1 reference values

Captured by `emmc_dump_controller_state` post-reset, pre-card-init:

| Register | Value | Meaning |
|----------|-------|---------|
| CAPABILITIES | `0x226DC881` | advertised base 200 MHz, 3.0 V only, 8-bit, embedded, ADMA2/SDMA |
| CAPABILITIES_HIGH | `0x08000007` | SDR50/SDR104/DDR50 |
| HOST_CONTROL_1 | `0xC0` | card-detect test level = present |
| POWER_CONTROL | `0x0D` | 3.0 V + power on |
| INT_ENABLE | `0xFFFF7FFF` | status bits enabled |
| PRESENT_STATE | `0x03F700F0` | card stable, CMD/DAT lines high |
| HOST_CTRL3 | `0x01` (byte) | conflict-check at reset default |
| EMMC_CONTROL | `0x0D` | CARD_IS_EMMC set; RST_N deasserted, RST_N_OE on |
| DLL_RXCLK | `0x00000000` | upstream low-speed value (RX inverted) |
| SDHCI_VERSION | `0x0005` | SDHCI spec 4.10 |

(The `DLL_RXCLK = 0x20000000` no-inverter value appears in some
earlier dumps — that was a hypothesis since reverted; see the
status section above.)

Re-run the test suite to capture a fresh dump if any of these
surprise you on a later cycle.

## Related documents

- `docs/datasheets/INDEX.md` — the TRM and spec PDFs; TRM Part 2
  Ch7 is the eMMC chapter, Ch6 the SDMMC0 (DW MSHC) chapter.
- `docs/016-physical-memory-map.md` — the `0xFE31_0000` base.
- `docs/017-clocks-and-timers.md` — the 5 clocks, 5 resets, and
  the `CCLK_EMMC` source mux.
- `docs/019-board-pinmux.md` — pinmux / pull / drive-strength /
  input-enable register layout.
- `issues/110a-emmc-controller-driver.md` — the bring-up issue.
- `issues/110h-phase-1-bringup-test-suite.md` — the diagnostic
  runner that produced these dumps.
