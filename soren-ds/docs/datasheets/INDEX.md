# Hardware datasheets and specifications

Reference PDFs for the chip and standards Soren DS bring-up
depends on. These are the canonical documents we should reach
for first when something doesn't behave as expected. All were
downloaded once to avoid re-fetching during development.

## Files

### Rockchip RK3568 — the SoC

- **`rk3568-trm-part1.pdf`** (12 MB) — Technical Reference Manual
  Part 1, version 1.3, September 2022. Covers the system /
  CRU / GRF / memory map / boot ROM. Read this for clock-gate
  registers, soft-reset registers, GRF IOMUX/PULL/DRV register
  layouts, the chip's address-space organisation. Source:
  Rockchip's opensource.rock-chips.com.
- **`rk3568-trm-part2.pdf`** (120 MB, 2583 pages) — TRM Part 2,
  version 1.1, March 2021. Covers every peripheral controller
  in detail: eMMC (dwcmshc), SDMMC0/1, USB 2.0 PHY, USB 3.0,
  VOP2 display controller, MIPI DSI, PWM, I²C, UART, SARADC,
  etc. Each peripheral chapter has the full register address
  map, bit-by-bit field descriptions, and reset values. This
  is where bring-up bugs almost always get answered. Source:
  github.com/heitbaum/rk3568 mirror (not officially released
  by Rockchip).
- **`rk3568-datasheet.pdf`** (3.4 MB) — chip-overview datasheet
  v1.2, June 2021. High-level pin maps, package info,
  electrical characteristics. Less useful than the TRM for
  software bring-up.

### Industry standards

- **`sdhci-host-controller-spec.pdf`** (2.4 MB, 234 pages) — SD
  Association's Host Controller Simplified Specification v4.20.
  Defines the standard SDHCI register set (offsets, bit
  layouts, response register format, command-issue model). The
  RK3568's eMMC controller (dwcmshc) is built on top of this
  spec — its base register set follows the standard, with
  Rockchip-specific extensions in the vendor area above offset
  0x500.
- **`jedec-emmc-5.1.pdf`** (6.3 MB, 352 pages) — JEDEC standard
  JESD84-B51, February 2015. Defines the eMMC protocol at the
  wire level: every CMD (0 through 56), every response type
  (R1, R2, R3, R5, R6, R7), the card's state machine
  (Idle → Ready → Ident → Stand-by → Trans → ...), the CID /
  CSD / EXT_CSD register formats. Read this when a command's
  expected card-side behaviour is unclear.

### Vendor IP

- **`synopsys-dwc-mshc.pdf`** (1.5 MB, 21 pages) — Synopsys
  Mobile Storage Host Controller databook excerpt. The full
  databook is 646 pages and behind a Synopsys NDA; what we
  have here is the publicly available chapter excerpt
  covering the Register Address Map and a few timing
  guidelines. For dwcmshc-specific vendor-area register
  details (HOST_CTRL3, EMMC_CONTROL, DLL_*, etc.) the RK3568
  TRM Part 2's eMMC chapter is usually a better reference
  because it documents the Rockchip integration directly.

## When to read each one

| Symptom                              | First doc          |
|--------------------------------------|--------------------|
| Pinmux / pull / drive-strength       | TRM Part 1, GRF    |
| Clock-gate or reset register         | TRM Part 1, CRU    |
| Address-space layout                 | TRM Part 1         |
| Peripheral controller registers      | TRM Part 2         |
| SDHCI standard register field        | SDHCI spec         |
| eMMC card behaviour at the protocol  | JEDEC eMMC 5.1     |
| dwcmshc vendor-area quirk            | TRM Part 2 + Synopsys excerpt |
| RK3568 board-level integration       | Anbernic device tree (`libs/sd-image-parts/`) |

## What's missing

- **Synopsys DWC_mshc full databook** — only the partial excerpt
  is publicly accessible. Full version is behind Synopsys NDA.
  Not strictly needed because TRM Part 2 documents the
  Rockchip-specific instance.
- **Rockchip RK817 PMIC datasheet** — we have a reference in
  `docs/021-pmic-and-regulators.md` but not the full PDF.
  Findable via search if and when we need to talk to the PMIC
  directly.
