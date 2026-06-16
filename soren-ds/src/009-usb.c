/*
 * 009-usb.c — USB 2.0 PHY and DWC3 controller bring-up
 *
 * Brings the RK3568's USB 3.0 OTG controller (a Synopsys DesignWare
 * DWC3) up in device mode at USB 2.0 high speed. The SuperSpeed
 * (USB 3.0) PHY is left untouched — phase 1's CDC-ACM debug stream
 * never needs more bandwidth than USB 2.0 provides, and skipping
 * the SuperSpeed PHY is a smaller bring-up surface.
 *
 * The path through the hardware is:
 *
 *   USB-C port  →  USB 2.0 PHY (analog → digital)
 *               →  DWC3 controller (USB protocol engine)
 *               →  Our descriptor logic in 109b
 *
 * Step 1 in this file takes the USB 2.0 PHY out of suspend by
 * writing the right value into the chip's GRF (general register
 * file) — the PHY's per-instance reset and operational state lives
 * in GRF registers rather than in the PHY's own MMIO window, which
 * is Rockchip's convention. The GRF uses a write-enable scheme: the
 * upper 16 bits of every register form a mask of which lower bits
 * the write actually changes, so writes leave untouched bits
 * untouched.
 *
 * Step 2 issues a soft reset to the DWC3 controller through its
 * global control register, waits for the reset to complete, and
 * then writes the port-capability direction field to "device mode"
 * (the controller can serve as host, device, or full OTG; we pick
 * device).
 *
 * Step 3 reads back the DWC3 identification register and verifies
 * its upper 16 bits read as 0x5533 (the ASCII for "U3", the
 * Synopsys-published identifier for the DWC3 IP). A mismatch
 * indicates either an MMIO write that did not land (a clock that
 * was not enabled, a controller still held in external reset)
 * or — far less likely — that the chip is not what we think it is.
 *
 * No descriptor logic, no endpoint configuration, no host
 * interaction yet — that is issue 109b's job. The success of this
 * file is observable on the laptop side as raw USB activity on
 * plug-in (the host kernel sees reset and link-up signals) even
 * though enumeration still fails.
 *
 * Clocks: u-boot enables the USB controller and PHY clocks during
 * its own boot path so the USB-C charging path can detect a
 * connected charger. We rely on that — touching the CRU adds a
 * pile of register surface for no benefit at this stage. If a
 * future bring-up failure traces back to a disabled clock, the
 * CRU control lives at 0xFDD20000 per the memory map.
 */

#include <stdint.h>

/* MMIO write/read helpers. Same volatile-pointer pattern the PWM
 * driver in 003-pwm.c uses. */
static inline void mmio_write32(uintptr_t address, uint32_t value)
{
    *(volatile uint32_t *)address = value;
}

static inline uint32_t mmio_read32(uintptr_t address)
{
    return *(volatile uint32_t *)address;
}

/* Rough busy-wait. The kernel has no timer yet — issue 502 brings
 * one up. For phase 1's one-shot hardware bring-up at boot, a loop
 * that runs N nop instructions is plenty. Tuning is not critical
 * because the DWC3's soft-reset completion is observable by polling
 * its status register, so the wait just gives the hardware enough
 * time before we look.
 *
 * Pets the chip's watchdog at the start (issue 103g — the
 * watchdog's BSP-default timeout is short enough that even
 * microsecond-scale settling delays should pet to be safe). */
static void rough_delay(uint32_t loops)
{
    *(volatile uint32_t *)0xFE60000Cu = 0x76u;
    for (uint32_t i = 0; i < loops; i++) {
        __asm__ volatile ("nop");
    }
}

/* Bring up the USB 3.0 OTG controller's clocks and take it out of
 * hardware reset, before the per-PHY and per-controller register
 * configuration the rest of this file performs.
 *
 * The mainline-derived ROCKNIX u-boot on the SD-card boot path does
 * not enable these — its defconfig does not include the DWC3
 * driver and so does not pre-enable anything USB-related. Until
 * the kernel itself ungates the controller's clocks and deasserts
 * its hardware reset, the writes the rest of usb_init performs to
 * the DWC3 register window land on a peripheral that is not
 * running and either silently fail or stall the bus enough to
 * trigger an exception.
 *
 * Two writes do the work. The first ungates the three USB 3.0
 * OTG clocks in the main CRU's clock-gate register block — the
 * ACLK (the controller's register-access clock), the reference
 * clock, and the suspend clock. The second pair asserts then
 * deasserts the controller's hardware reset, putting it into its
 * post-reset state with its clocks ticking.
 *
 * See issue 109a and docs/017-clocks-and-timers.md for the wider
 * story. */
#define CRU_BASE              0xFDD20000u
#define CRU_CLKGATE_CON_10    (CRU_BASE + 0x0328u)
#define CRU_SOFTRST_CON_9     (CRU_BASE + 0x0424u)
#define USB3OTG0_CLKS_MASK    0x07000000u    /* mask bits 8,9,10 */
#define USB3OTG0_CLKS_ENABLE  0x07000000u    /* value bits 8,9,10 = 0 (ungate) */
#define USB3OTG0_RESET_BIT    (1u << 4)
#define USB3OTG0_RESET_MASK   (USB3OTG0_RESET_BIT << 16)

static void usb_clocks_and_reset_enable(void)
{
    /* Ungate the three USB 3.0 OTG controller clocks. */
    mmio_write32(CRU_CLKGATE_CON_10,
                 USB3OTG0_CLKS_MASK | USB3OTG0_CLKS_ENABLE);
    rough_delay(1000);

    /* Assert then deassert the controller's soft reset. The
     * controller comes out of this in its post-reset state, with
     * the clocks just ungated above already feeding it. */
    mmio_write32(CRU_SOFTRST_CON_9,
                 USB3OTG0_RESET_MASK | USB3OTG0_RESET_BIT);
    rough_delay(1000);
    mmio_write32(CRU_SOFTRST_CON_9,
                 USB3OTG0_RESET_MASK);
    rough_delay(1000);
}

/* USB 2.0 PHY 0 — General Register File. The PHY's reset and
 * suspend control bits live here rather than in the PHY's own
 * MMIO. Per the rk3568 inno-usb2 PHY driver in the Linux kernel:
 *
 *   GRF + 0x0004  phy_sus — bits [8:0] control the PHY's
 *                 power/suspend state. Value 0x1D1 is the
 *                 documented "normal operation" code; 0x1D2 is
 *                 "suspend."
 *
 * The Rockchip GRF write convention puts a write-enable mask in
 * the upper 16 bits of every register: bits [24:16] enable writes
 * to bits [8:0] etc. To write 0x1D1 into bits [8:0] without
 * disturbing anything else, we write (0x1FF << 16) | 0x1D1.
 */
#define USB2PHY0_GRF_BASE   0xFDCA0000u
#define USB2PHY0_GRF_SUS    0x0004u
#define PHY_SUS_NORMAL      0x01D1u
#define PHY_SUS_FIELD_MASK  0x01FFu

static void usb2_phy_bring_up(void)
{
    uint32_t write_mask = (PHY_SUS_FIELD_MASK << 16);
    uint32_t value = PHY_SUS_NORMAL & PHY_SUS_FIELD_MASK;
    mmio_write32((uintptr_t)(USB2PHY0_GRF_BASE + USB2PHY0_GRF_SUS),
                 write_mask | value);
    /* Let the PHY settle. Datasheet quotes a few microseconds; a
     * generous nop loop is more than enough. */
    rough_delay(10000);
}

/* DWC3 controller — the USB protocol engine.
 *
 * The RK3568's USB 3.0 OTG controller's MMIO window starts at
 * 0xFEC00000 (per the memory map). DWC3's documented register
 * file lives at controller_base + 0xC000; the global registers
 * start at offset 0xC100 within that file. Adding the controller
 * base gives absolute addresses for each register.
 *
 * Register offsets from the DWC3 driver in the Linux kernel
 * (drivers/usb/dwc3/core.h):
 *
 *   GCTL         0xC110  global control
 *   GSTS         0xC118  global status
 *   GSNPSID      0xC120  Synopsys controller ID
 *   DCFG         0xC700  device configuration
 *
 * GCTL bits:
 *   bit 11       CoreSoftReset
 *   bits 13:12   PrtCapDir   (1 = device, 2 = host, 3 = OTG)
 *
 * DCFG bits:
 *   bits 2:0     DevSpd      (0 = high-speed USB 2.0,
 *                             4 = SuperSpeed USB 3.0)
 *   bits 9:3     DevAddr     (0 at reset; the host assigns)
 */
#define DWC3_BASE       0xFEC00000u
#define DWC3_GCTL       (DWC3_BASE + 0xC110u)
#define DWC3_GSTS       (DWC3_BASE + 0xC118u)
#define DWC3_GSNPSID    (DWC3_BASE + 0xC120u)
#define DWC3_DCFG       (DWC3_BASE + 0xC700u)

#define GCTL_CORESOFTRESET   (1u << 11)
#define GCTL_PRTCAPDIR_SHIFT 12
#define GCTL_PRTCAPDIR_MASK  (0x3u << GCTL_PRTCAPDIR_SHIFT)
#define GCTL_PRTCAPDIR_DEVICE (0x1u << GCTL_PRTCAPDIR_SHIFT)

#define DCFG_DEVSPD_MASK     0x7u
#define DCFG_DEVSPD_HS       0x0u    /* USB 2.0 high speed */

/* Synopsys ID for DWC3 IP. The upper 16 bits read as 0x5533
 * ("U3" in ASCII); the lower 16 bits are a revision code that
 * varies between chip revisions. We check only the upper half. */
#define DWC3_SNPSID_UPPER_EXPECTED 0x5533u

static int dwc3_soft_reset_and_set_device_mode(void)
{
    /* Issue the soft reset, then wait. There is a documented
     * "wait for reset to complete" status bit we could poll, but
     * the rough_delay is simpler and the hardware takes much
     * less than the loop's worth of cycles. */
    uint32_t gctl = mmio_read32(DWC3_GCTL);
    mmio_write32(DWC3_GCTL, gctl | GCTL_CORESOFTRESET);
    rough_delay(10000);
    gctl = mmio_read32(DWC3_GCTL);
    mmio_write32(DWC3_GCTL, gctl & ~GCTL_CORESOFTRESET);
    rough_delay(10000);

    /* Set PrtCapDir to device mode. Read-modify-write to leave
     * the rest of GCTL alone. */
    gctl = mmio_read32(DWC3_GCTL);
    gctl &= ~GCTL_PRTCAPDIR_MASK;
    gctl |= GCTL_PRTCAPDIR_DEVICE;
    mmio_write32(DWC3_GCTL, gctl);

    /* Pin device speed to USB 2.0 high-speed. The DWC3 will
     * default to SuperSpeed if its SuperSpeed PHY were
     * configured; since we have not configured it, advertising
     * SuperSpeed would leave the controller stuck trying to use
     * a PHY that is not there. */
    uint32_t dcfg = mmio_read32(DWC3_DCFG);
    dcfg &= ~DCFG_DEVSPD_MASK;
    dcfg |= DCFG_DEVSPD_HS;
    mmio_write32(DWC3_DCFG, dcfg);

    /* Verify the controller is alive by reading its ID. If the
     * upper 16 bits don't match the Synopsys magic, something
     * before us went wrong — most likely a clock not enabled. */
    uint32_t snpsid = mmio_read32(DWC3_GSNPSID);
    if ((snpsid >> 16) != DWC3_SNPSID_UPPER_EXPECTED) {
        return -1;
    }
    return 0;
}

/* Public entry: bring up the USB 2.0 PHY and the DWC3 controller
 * into device mode at USB 2.0 high speed. Returns 0 on success
 * (controller alive, identified, configured for device mode) or
 * a negative value on failure. The caller decides what to do
 * with the failure — currently kernel_main lights the panic LED
 * since there is no richer diagnostic channel yet. */
int usb_init(void)
{
    usb_clocks_and_reset_enable();
    usb2_phy_bring_up();
    return dwc3_soft_reset_and_set_device_mode();
}
