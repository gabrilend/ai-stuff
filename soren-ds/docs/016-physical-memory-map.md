# Physical memory map

The Anbernic RG DS is a Rockchip RK3568 with 3 GB of LPDDR4
DRAM. Like every modern SoC, the chip exposes that DRAM and a
large collection of peripheral register windows in a single
unified 64-bit physical address space. This document catalogues
the whole space — the DRAM region the page allocator hands out,
the reserved sub-regions of DRAM that lower-layer firmware
keeps for itself, and every peripheral register block we have
identified.

Why pin all of it down here, even the peripherals we won't
touch for many issues: each peripheral driver later in phase 1
and beyond will need its register base address, and finding
those addresses one-at-a-time in the datasheet across many
sessions is wasteful. Doing the harvest once, here, lets every
later driver reference a known authoritative catalogue. The
peripheral bases also serve as a safety net for the page
allocator — it explicitly knows where DRAM ends, and every
peripheral region is outside that bound, but documenting the
boundary in both directions is cheap insurance against a
copy-paste mistake.

This document and the linker script in `src/kernel.ld` together
fully describe where everything in the system lives.

## DRAM regions

DRAM sits at the bottom of the physical address space, starting
at zero. The RK3568's memory controller maps up to 8 GB; this
particular device populates 3 GB. So the DRAM range is:

| Range                             | Notes                                    |
| --------------------------------- | ---------------------------------------- |
| `0x0000_0000` – `0xC000_0000`     | Three gigabytes of LPDDR4, populated.    |
| `0xC000_0000` – `0x2_0000_0000`   | Unpopulated. Bus errors if accessed.     |

Within the populated DRAM, lower-layer firmware claims the
bottom slice for its own use. The page allocator must stay
above this slice.

| Range                             | Owner                                     |
| --------------------------------- | ----------------------------------------- |
| `0x0000_0000` – `0x0020_0000`     | Secure firmware (BL31 / ATF). Untouchable. |
| `0x0020_0000` – `0x0200_0000`     | Bootloader working set. The bootloader on the active path lives somewhere here along with its heap, its decompression scratch, and any framebuffer it set up. Treated as opaque pre-kernel territory. |
| `0x0200_0000` – `__stack_top`     | SoreOS kernel image, including its stack. |
| `__stack_top` – `0xC000_0000`     | Free DRAM. This is what the page allocator hands out. |

`__stack_top` is the linker symbol defined in `src/kernel.ld`;
right now it sits a few KB above `0x0200_0000` because the
kernel itself is small. As the kernel grows it pushes
`__stack_top` upward; the allocator's pool starts wherever
`__stack_top` lands at the end of a particular build.

### Caveats and open questions

The kernel's load address of `0x0200_0000` is the address
ROCKNIX's u-boot uses on the SD-card development boot path
(its compiled-in `kernel_addr_r` environment value). The same
address is baked into the Android boot.img header the
boot-partition writer in `src/013-boot-image.c` emits, so once
the eMMC takeover lands Anbernic's u-boot loads our kernel to
the same place. The linker pins the kernel at that address;
both boot paths produce the same in-memory layout, and the
literal-pool addresses the linker resolved match the physical
addresses the running kernel actually inhabits.

The pre-kernel boundary moved from `0x0028_0000` to
`0x0200_0000` in issue 103d. The earlier value was a guess
inherited from Anbernic's Android conventions; ROCKNIX's
mainline-derived u-boot uses the higher value, and the first
SD-boot hardware test surfaced the mismatch as a kernel that
loaded and was jumped to but read its own data from the wrong
memory. The new boundary is verified against the u-boot
binary's compiled-in defaults rather than guessed. If a future
boot shows allocator corruption near the bottom of the pool,
the actual u-boot reserved region may extend higher than
`0x0200_0000`; the answer would be to bump that boundary up
and rebuild.

The 3 GB DRAM size is from Anbernic's spec sheet. The RK3568
memory controller can report the populated size at boot through
the CRU and DDR controller registers, but we have no reason to
trust the spec sheet less than that hardware report. If DRAM
faults appear in the upper part of the range, that is the next
place to look.

The GPU has a memory carve-out we have not located. The phase 1
demo does not use the GPU, so the carve-out is irrelevant until
a phase that does. When the day comes, the place to look is the
Rockchip Android u-boot configuration on the Anbernic image —
it pins the carve-out address as a boot argument.

## Peripheral register windows

All RK3568 peripherals live above DRAM, in the address range
roughly `0xFC00_0000` to `0xFF00_0000`. Bus accesses outside
this range and outside DRAM produce bus faults.

Addresses below are from the upstream device tree at
`arch/arm64/boot/dts/rockchip/rk356x-base.dtsi` in Heiko
Stuebner's `linux-rockchip` tree (the same source the hardware
overview at `014-hardware-overview.md` harvested from).

### Interrupt and clock infrastructure

| Base          | Size      | Block            |
| ------------- | --------- | ---------------- |
| `0xFD40_0000` | `0x10000` | GIC distributor  |
| `0xFD46_0000` | `0x80000` | GIC redistributors |
| `0xFDD9_0000` | `0x1000`  | PMU (power-management) — earlier version of this doc had this row at `0xFD80_0000` (the address of USB2 host 0 EHCI per the device tree). Crossed with the USB-controller transcription errors caught alongside the DWC3 controller's address bug; corrected against the device tree we extracted from ROCKNIX. |
| `0xFDC2_0000` | `0x10000` | PMU GRF          |
| `0xFDC5_0000` | `0x1000`  | Pipe GRF         |
| `0xFDC6_0000` | `0x10000` | General Register File (GRF) |
| `0xFDC8_0000` | `0x1000`  | Pipe PHY GRF 1   |
| `0xFDC9_0000` | `0x1000`  | Pipe PHY GRF 2   |
| `0xFDCA_0000` | `0x8000`  | USB2 PHY 0 GRF   |
| `0xFDCA_8000` | `0x8000`  | USB2 PHY 1 GRF   |
| `0xFDD0_0000` | `0x1000`  | PMU CRU (clock controller for the PMU domain) |
| `0xFDD2_0000` | `0x1000`  | Main CRU (clock controller for the main domain) |

The GRF blocks are the "general register files" — they hold
chip-wide iomux and miscellaneous control registers that are
not part of any single peripheral. The pinctrl driver writes
into these to change pin functions.

### GPIO banks

| Base          | Size    | Bank   | Location               |
| ------------- | ------- | ------ | ---------------------- |
| `0xFDD6_0000` | `0x100` | GPIO0  | PMU domain (always-on) |
| `0xFE74_0000` | `0x100` | GPIO1  | Main domain            |
| `0xFE75_0000` | `0x100` | GPIO2  | Main domain            |
| `0xFE76_0000` | `0x100` | GPIO3  | Main domain            |
| `0xFE77_0000` | `0x100` | GPIO4  | Main domain            |

Each bank exposes 32 pins. GPIO0 is in the PMU domain so it
stays alive during sleep — relevant to the Hall switch wake-up
input on GPIO0 PC3 (per the hardware overview).

### Storage and external connectivity

| Base          | Size       | Block                              |
| ------------- | ---------- | ---------------------------------- |
| `0xFE00_0000` | `0x4000`   | SDMMC2 (WiFi SDIO on this device)  |
| `0xFE01_0000` | `0x10000`  | GMAC1 (gigabit Ethernet MAC)       |
| `0xFE26_0000` | `0x4000`   | PCIe 2.x lane                      |
| `0xFE2B_0000` | `0x4000`   | SDMMC0 (external microSD slot)     |
| `0xFE2C_0000` | `0x4000`   | SDMMC1                             |
| `0xFE30_0000` | `0x4000`   | SFC (serial flash controller)      |
| `0xFE31_0000` | `0x10000`  | SDHCI (internal eMMC, 8-bit non-removable) |

The Anbernic RG DS uses SDHCI for the eMMC, SDMMC0 for the
external microSD, and SDMMC2 for the WiFi SDIO — per the
hardware overview. GMAC1, PCIe, SDMMC1, and SFC are present in
the chip but not wired up on this board.

### Audio interfaces

| Base          | Size     | Block        |
| ------------- | -------- | ------------ |
| `0xFE40_0000` | `0x1000` | I2S0 (8-channel) |
| `0xFE41_0000` | `0x1000` | I2S1 (8-channel) |
| `0xFE42_0000` | `0x1000` | I2S2 (2-channel) |
| `0xFE43_0000` | `0x1000` | I2S3 (2-channel) |
| `0xFE44_0000` | `0x1000` | PDM           |
| `0xFE46_0000` | `0x1000` | SPDIF        |

### Direct memory access

| Base          | Size     | Block |
| ------------- | -------- | ----- |
| `0xFE53_0000` | `0x4000` | DMAC0 |
| `0xFE55_0000` | `0x4000` | DMAC1 |

### I²C

| Base          | Size     | Bus  | Notes                              |
| ------------- | -------- | ---- | ---------------------------------- |
| `0xFDD4_0000` | `0x1000` | I2C0 | PMU domain — RK817 PMIC, SYR827 CPU regulator, CW2015 (disabled) |
| `0xFE5A_0000` | `0x1000` | I2C1 |                                    |
| `0xFE5B_0000` | `0x1000` | I2C2 | AW87391 audio amplifiers           |
| `0xFE5C_0000` | `0x1000` | I2C3 | Goodix GT911 (bottom touch panel)  |
| `0xFE5D_0000` | `0x1000` | I2C4 |                                    |
| `0xFE5E_0000` | `0x1000` | I2C5 | Goodix GT911 (top touch panel)     |

### UART

| Base          | Size    | Port   | Notes                                |
| ------------- | ------- | ------ | ------------------------------------ |
| `0xFDD5_0000` | `0x100` | UART0  | PMU domain                           |
| `0xFE65_0000` | `0x100` | UART1  | RTL8821CS Bluetooth                  |
| `0xFE66_0000` | `0x100` | UART2  | Often the debug UART on RK3568 boards (we don't use it; RG DS exposes no header for it) |
| `0xFE67_0000` | `0x100` | UART3  |                                      |
| `0xFE68_0000` | `0x100` | UART4  |                                      |
| `0xFE69_0000` | `0x100` | UART5  |                                      |
| `0xFE6A_0000` | `0x100` | UART6  |                                      |
| `0xFE6B_0000` | `0x100` | UART7  |                                      |
| `0xFE6C_0000` | `0x100` | UART8  |                                      |
| `0xFE6D_0000` | `0x100` | UART9  |                                      |

### SPI

| Base          | Size     | Bus  |
| ------------- | -------- | ---- |
| `0xFE61_0000` | `0x1000` | SPI0 |
| `0xFE62_0000` | `0x1000` | SPI1 |
| `0xFE63_0000` | `0x1000` | SPI2 |
| `0xFE64_0000` | `0x1000` | SPI3 |

### PWM controllers and channels

Each "PWM" block on the RK3568 is a single channel; four
channels share a controller block. The arrangement:

| Controller block | Base          | Channels | Notes (RG DS) |
| ---------------- | ------------- | -------- | ------------- |
| PWM0 controller  | `0xFDD7_0000` | PWM0-PWM3 | — |
| PWM1 controller  | `0xFE6E_0000` | PWM4-PWM7 | PWM5/6/7 drive the three LEDs (green / amber / red) |
| PWM2 controller  | `0xFE6F_0000` | PWM8-PWM11 | — |
| PWM3 controller  | `0xFE70_0000` | PWM12-PWM15 | — |

Each channel within a controller is 0x10 bytes from the
controller base:

| Channel | Address      | Used for       |
| ------- | ------------ | -------------- |
| PWM0    | `0xFDD7_0000` |                |
| PWM1    | `0xFDD7_0010` |                |
| PWM2    | `0xFDD7_0020` |                |
| PWM3    | `0xFDD7_0030` |                |
| PWM4    | `0xFE6E_0000` |                |
| PWM5    | `0xFE6E_0010` | green LED      |
| PWM6    | `0xFE6E_0020` | amber LED      |
| PWM7    | `0xFE6E_0030` | red LED        |
| PWM8    | `0xFE6F_0000` |                |
| PWM9    | `0xFE6F_0010` |                |
| PWM10   | `0xFE6F_0020` |                |
| PWM11   | `0xFE6F_0030` |                |
| PWM12   | `0xFE70_0000` |                |
| PWM13   | `0xFE70_0010` |                |
| PWM14   | `0xFE70_0020` |                |
| PWM15   | `0xFE70_0030` |                |

Within each PWM channel, the 16-byte register window is:
`+0x00` counter, `+0x04` duty, `+0x08` period, `+0x0C` control.
The LED driver in `src/003-pwm.c` hard-codes these offsets.

### Sensors

| Base          | Size    | Block                           |
| ------------- | ------- | ------------------------------- |
| `0xFE60_0000` | `0x100` | Watchdog                        |
| `0xFE71_0000` | `0x100` | TSADC (thermal sensor)          |
| `0xFE72_0000` | `0x100` | SARADC (general-purpose ADC, drives the HOME and PLAY ADC buttons per the hardware overview) |

The watchdog is the hardware piece the safety document
(`notes/safety/000-bricking-and-recovery.md`) requires us to pet
once it is configured. Phase 1 does not yet configure it; the
issue that does will reference this base address.

### USB controllers and PHYs

| Base          | Size       | Block                            |
| ------------- | ---------- | -------------------------------- |
| `0xFE83_0000` | `0x100`    | combphy1 (USB / PCIe combo PHY)  |
| `0xFE84_0000` | `0x100`    | combphy2 (USB / PCIe combo PHY)  |
| `0xFE8A_0000` | `0x10000`  | USB2 PHY 0                       |
| `0xFE8B_0000` | `0x10000`  | USB2 PHY 1                       |
| `0xFCC0_0000` | `0x40_0000`| USB3 OTG controller (DWC3) — wired to USB-C. The first iteration of this document said `0xFEC0_0000`, copied from an earlier Rockchip BSP version that used a different bus mapping; the actual address on this device, per the device tree we extracted from ROCKNIX, is `0xFCC0_0000`. The wrong address was the fault site for the USB cycling we hit during phase-1 hardware testing. |
| `0xFD00_0000` | `0x40_0000`| USB3 host 1 (xHCI) — not wired on RG DS |
| `0xFD80_0000` | `0x4_0000` | USB2 host 0 EHCI                 |
| `0xFD84_0000` | `0x4_0000` | USB2 host 0 OHCI                 |
| `0xFD88_0000` | `0x4_0000` | USB2 host 1 EHCI                 |
| `0xFD8C_0000` | `0x4_0000` | USB2 host 1 OHCI                 |

The USB controller issue 109 will bring up will be USB3 host 0
in device (OTG) mode, since that is the controller connected to
the USB-C port.

### Display and video

| Base          | Size      | Block                            |
| ------------- | --------- | -------------------------------- |
| `0xFE85_0000` | `0x10000` | DSI D-PHY 0 (bottom panel)       |
| `0xFE86_0000` | `0x10000` | DSI D-PHY 1 (top panel)          |
| `0xFE87_0000` | `0x10000` | CSI D-PHY (camera, unused here)  |
| `0xFEA0_0000` | `0x3000`  | VOP2 (Video Output Processor)    |
| `0xFEA0_4000` | `0x1000`  | VOP2 gamma LUT                   |
| `0xFEA4_0000` | `0x20000` | HDMI (not wired on the RG DS)    |

Issues 111a and 111b will bring up VOP2 and both DSI D-PHYs to
drive the two panels.

### Graphics, video encode/decode

| Base          | Size      | Block                       |
| ------------- | --------- | --------------------------- |
| `0xFDE6_0000` | `0x4000`  | Mali-G52 GPU                |
| `0xFDEA_A000` | `0x800`   | VPU (video decoder)         |
| `0xFDEB_0000` | `0x180`   | RGA (2D graphics accelerator) |
| `0xFDEE_E000` | `0x800`   | VEPU (video encoder)        |
| `0xFDFF_E000` | `0x200`   | VICAP (video input capture) |

Phase 1 does not bring up any of these. They are catalogued so a
later phase that wants hardware video encode or 2D blits knows
where to look.

## Why we do not use the address space above the peripheral range

Anything above the documented peripheral range (`> 0xFEFF_FFFF`
or so) on the RK3568 is either reserved by the chip vendor for
future use or aliased to other regions. Touching it produces
bus faults at best and undefined behaviour at worst. The page
allocator's pool is bounded above by `0xC000_0000` (the end of
populated DRAM); the peripheral range above that is the
hardware's, not ours.

## microSD card region layout (LBAs, not chip addresses)

Separate from the chip's physical address space, the kernel
reserves two regions *on the external microSD card* for its own
use. These are logical block addresses (512-byte sectors) on the
card, both chosen to sit far above the bootable FAT partition (the
first ~272 MB) so the card stays bootable. Each constant is
mirrored between the kernel source and a lab-side script; the two
must change together.

| SD LBA | Offset | Region | Kernel source | Lab script |
| ------ | ------ | :----- | :------------ | :--------- |
| `0x20_0000` | ~1 GB | eMMC backup destination — the eMMC→SD dump lands here | `emmc_backup_to_sd` arg in `src/002-main.c` | `dump-from-sd` (`BACKUP_LBA`) |
| `0x40_0000` | ~2 GB | Debug log ring — `debug_write` flushes narration here | `LOG_SD_REGION_START` in `src/017-debug-log.c` | `dump-from-sd` (`DEBUG_LOG_LBA`) |

The hardware-probe battery used to claim two more card regions here —
an "active probe" at `0x10_0000` and a "catalog" at `0x18_0000` that
lab-side tooling wrote onto the card after flashing. Those are gone:
the probes are compiled into the kernel now (a `scripts/build --probes`
build embeds every `input/probes/*.probe` and runs them all on boot),
so nothing probe-related lives on the card any more. The probe results
still flow through the debug-log region above, and `dump-from-sd` still
splits the swept log into one file per probe. See issue 110i for why
the delivery moved in-tree.
