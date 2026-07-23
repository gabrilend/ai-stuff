/*
 * 021-vop2.c — VOP2 display controller bring-up (issue 111a)
 *
 * The VOP2 (Video Output Processor v2) is the block that reads pixels out of
 * framebuffers in DRAM and scans them, on a fixed timing, to the two panels.
 * It is the bottom of the display stack: everything above it — the MIPI DSI
 * controllers, the D-PHYs, the panel init, the framebuffers — feeds or is fed
 * by VOP2. This file is the first, smallest, safest step: get the controller
 * clocked, out of reset, and proven alive, with both video outputs left
 * parked (in standby) so nothing scans until the rest of the stack is up.
 *
 * The full display bring-up sequence this begins:
 *   vop2_init  (here, 111a)  -> DSI/D-PHY (111b) -> panel init (111c)
 *   -> framebuffer + scanout (111d) -> a visible pixel (112).
 *
 * Recon (docs/023-display-controller.md, confirmed against the board device
 * tree and the display-presence probe): VOP2 is at 0xFE040000; its version
 * register reads 0x40158023 on this board; its clocks and resets both reset
 * to ON / released at power-on, so a clean boot already arrives with the
 * block clocked. The ungate / reset-release below are therefore defensive —
 * they cost nothing on a clean boot and keep this correct even if an earlier
 * stage had gated the block. Unlike the display-presence PROBE (which reads
 * VOP2 then restores the clocks to as-found, because it only checks
 * presence), this DRIVER leaves VOP2 clocked and out of reset: we are
 * bringing it up to keep, not just to look.
 *
 * vop2_init() is written and ready but is NOT yet wired into kernel_main —
 * the display path only becomes useful once 111b-d land, so wiring the whole
 * sequence in is a later, deliberate step. The display-presence probe already
 * exercises the underlying reachability on hardware today.
 */

#include <stdint.h>

extern void debug_write(const char *text);

/* {{{ static inline uint32_t mmio_r32() */
static inline uint32_t mmio_r32(uint32_t a)
{
    return *(volatile uint32_t *)(uintptr_t)a;
}
/* }}} */

/* {{{ static inline void mmio_w32() */
static inline void mmio_w32(uint32_t a, uint32_t v)
{
    *(volatile uint32_t *)(uintptr_t)a = v;
}
/* }}} */

/* {{{ static void busy_delay() */
/* A rough spin — long enough to let a clock ungate / reset release settle
 * before we read back the version. Not calibrated to wall-clock. */
static void busy_delay(uint32_t n)
{
    for (volatile uint32_t i = 0; i < n; i++) {
        /* the read/write of i is the delay */
    }
}
/* }}} */

/* {{{ static void write_hex32() */
/* Emit a 32-bit value as "0x" + eight hex digits through the console — the
 * kernel has no printf, so bring-up narration spells numbers out by hand. */
static void write_hex32(uint32_t v)
{
    static const char digits[] = "0123456789ABCDEF";
    char out[11];
    out[0] = '0';
    out[1] = 'x';
    for (int i = 0; i < 8; i++) {
        out[2 + i] = digits[(v >> ((7 - i) * 4)) & 0xF];
    }
    out[10] = 0;
    debug_write(out);
}
/* }}} */

/* VOP2 register facts (RK3568 TRM Part2 Ch13; bases from the board device
 * tree; version value observed on this board — see docs/023). */
#define VOP2_BASE              0xFE040000u
#define VOP2_VERSION           (VOP2_BASE + 0x0004u)
#define VOP2_VERSION_EXPECTED  0x40158023u
/* Per-VP post-process control; bit 31 = standby (resets to 1 = parked).
 * VP0 drives DSI0/bottom, VP1 drives DSI1/top. 111d clears standby to scan. */
#define VOP2_VP0_DSP_CTRL      (VOP2_BASE + 0x0C00u)
#define VOP2_VP1_DSP_CTRL      (VOP2_BASE + 0x0D00u)
#define VP_STANDBY_BIT         (1u << 31)

/* CRU clock-gate and reset for VOP2 (RK3568 TRM Part1 CRU; resolved by the
 * display-presence probe). These are write-mask registers: the high 16 bits
 * name which low bits the write applies to, so a raw write-back no-ops — the
 * (mask<<16)|value form is mandatory. Clearing a gate bit ENABLES the clock;
 * clearing a reset bit RELEASES the reset. */
#define CRU_CLKGATE_CON20      0xFDD20350u   /* VOP + VO bus clocks, bits 2..12 */
#define CRU_VOP_CLK_UNGATE     0x1FFC0000u   /* mask 0x1FFC, value 0 = all on   */
#define CRU_SOFTRST_CON16      0xFDD20440u   /* VOP resets, bits 0..8           */
#define CRU_VOP_RST_RELEASE    0x01FF0000u   /* mask 0x01FF, value 0 = released */

/* {{{ int vop2_init() */
/* Bring the VOP2 controller up to a known-good, quiet state (issue 111a):
 * clocks on, out of reset, version verified, both video ports left parked.
 * Returns 0 if the controller answered with its expected version, -1 if not
 * (a mismatch means the block is gated, mis-based, or a different revision —
 * the caller should not build the DSI/panel path on top of a controller that
 * did not identify itself). Narrates each step so a hardware run pins the
 * failing step. */
int vop2_init(void)
{
    debug_write("[vop2] bring-up (111a): ungate clocks + release reset\r\n");
    mmio_w32(CRU_CLKGATE_CON20, CRU_VOP_CLK_UNGATE);   /* defensive: on at boot */
    mmio_w32(CRU_SOFTRST_CON16, CRU_VOP_RST_RELEASE);  /* defensive: released   */
    busy_delay(20000u);

    uint32_t version = mmio_r32(VOP2_VERSION);
    debug_write("[vop2] version = ");
    write_hex32(version);
    if (version == VOP2_VERSION_EXPECTED) {
        debug_write("  (alive, expected)\r\n");
    } else {
        debug_write("  MISMATCH — expected ");
        write_hex32(VOP2_VERSION_EXPECTED);
        debug_write(" (gated? mis-based? other rev?)\r\n");
        return -1;
    }

    /* Report the two video ports' standby state. Both reset to standby=1
     * (parked), which is exactly what 111a wants — outputs stay off until
     * 111d has framebuffers to scan. We read and narrate rather than write:
     * VOP2 is double-buffered (changes need a CFG_DONE latch), and there is
     * nothing to enable yet, so touching them here would only add risk. */
    uint32_t vp0 = mmio_r32(VOP2_VP0_DSP_CTRL);
    uint32_t vp1 = mmio_r32(VOP2_VP1_DSP_CTRL);
    debug_write("[vop2] VP0 standby=");
    debug_write((vp0 & VP_STANDBY_BIT) ? "1" : "0");
    debug_write(" (bottom/DSI0), VP1 standby=");
    debug_write((vp1 & VP_STANDBY_BIT) ? "1" : "0");
    debug_write(" (top/DSI1) — outputs parked until 111d\r\n");

    debug_write("[vop2] controller alive and quiet\r\n");
    return 0;
}
/* }}} */

/* ---- VOP2 scanout (issue 111d) ------------------------------------------
 * Point a video port at a framebuffer and start it scanning to its MIPI
 * panel. Register facts from TRM Part2 Ch13 (extracted + read directly):
 *
 *   System (base 0xFE040000): REG_CFG_DONE @ 0x00 (hiword-masked; bit15
 *     global-enable, bit N per-VP latch), DSP_INFACE_EN @ 0x28 (mipi_out_en
 *     bit4 + VP-mux 17:16; mipi1_out_en bit20 + VP-mux 22:21).
 *   VP / POST (VP0 @ 0x0C00, VP1 @ 0x0D00): DSP_CTRL +0x00 (bit31 standby,
 *     bits3:0 dsp_out_mode=0 for RGB888), HACT_INFO +0x34, VACT_INFO +0x38,
 *     HTOTAL_HS_END +0x48 = (htotal<<16)|hsync, HACT_ST_END +0x4C =
 *     (hact_st<<16)|hact_end, VTOTAL_VS_END +0x50, VACT_ST_END +0x54.
 *   Esmart layer (Esmart0 @ 0x1800, Esmart1 @ 0x1A00): REGION0_CTRL +0x10
 *     (data_fmt bits5:1: 0=ARGB8888; mst_en bit0), MST_YRGB +0x14 (fb addr),
 *     VIR +0x1C (stride in words = width for ARGB8888), ACT_INFO +0x20 =
 *     ((h-1)<<16)|(w-1), DSP_INFO +0x24 (same), DSP_OFFSET +0x28 = 0.
 *
 * Panel mode: 640x480, from the board DTB (docs/023). [FLAG] the porch field
 * order (active, front, sync, back) is the best reading of the ROCKNIX timing
 * string (~80%; the vertical sync=2 is the tell). If the first image rolls or
 * shifts, swap the porch fields here — it will not stop the panel lighting.
 * [FLAG] the overlay LAYER_SEL/PORT_SEL are left at reset, which already route
 * Esmart0->VP0 and Esmart1->VP1; if a configured framebuffer does not appear,
 * the overlay mixer's per-port layer count is the next thing to set.
 * [FLAG] MST_YRGB is 32-bit, so the framebuffer must sit below 4 GiB physical. */
#define VOP2_SYS_CFG_DONE   (VOP2_BASE + 0x0000u)
#define VOP2_SYS_DSP_INFACE (VOP2_BASE + 0x0028u)

#define MODE_HACT   640u
#define MODE_HFP    260u
#define MODE_HSYNC  220u
#define MODE_HBP    260u
#define MODE_VACT   480u
#define MODE_VFP     10u
#define MODE_VSYNC    2u
#define MODE_VBP     16u

/* {{{ void vop2_scanout() */
/* Configure one video port + its Esmart layer to scan `fb_addr` full-screen
 * to its MIPI panel, leave standby, and commit. `iface_bits` are the
 * DSP_INFACE_EN bits enabling this VP's MIPI output (OR-ed into the shared
 * system register); `cfg_done_bit` is the port's latch bit (0=VP0, 1=VP1). */
void vop2_scanout(uint32_t vp_base, uint32_t esmart_base,
                  uint32_t iface_bits, uint32_t cfg_done_bit, uint32_t fb_addr)
{
    /* Esmart window -> framebuffer, full-screen, ARGB8888. */
    uint32_t act = ((MODE_VACT - 1u) << 16) | (MODE_HACT - 1u);
    mmio_w32(esmart_base + 0x14u, fb_addr);       /* MST_YRGB   */
    mmio_w32(esmart_base + 0x1Cu, MODE_HACT);     /* VIR stride (words) */
    mmio_w32(esmart_base + 0x20u, act);           /* ACT_INFO   */
    mmio_w32(esmart_base + 0x24u, act);           /* DSP_INFO   */
    mmio_w32(esmart_base + 0x28u, 0u);            /* DSP_OFFSET */
    mmio_w32(esmart_base + 0x10u, 0x00000001u);   /* ARGB8888 + enable */

    /* VP timing (TRM Ch13: high half = total/active-start, low = sync/end). */
    uint32_t htotal = MODE_HACT + MODE_HFP + MODE_HSYNC + MODE_HBP;
    uint32_t vtotal = MODE_VACT + MODE_VFP + MODE_VSYNC + MODE_VBP;
    uint32_t hact_st = MODE_HSYNC + MODE_HBP, hact_end = hact_st + MODE_HACT;
    uint32_t vact_st = MODE_VSYNC + MODE_VBP, vact_end = vact_st + MODE_VACT;
    mmio_w32(vp_base + 0x48u, (htotal << 16) | MODE_HSYNC);
    mmio_w32(vp_base + 0x4Cu, (hact_st << 16) | hact_end);
    mmio_w32(vp_base + 0x50u, (vtotal << 16) | MODE_VSYNC);
    mmio_w32(vp_base + 0x54u, (vact_st << 16) | vact_end);
    mmio_w32(vp_base + 0x34u, (hact_st << 16) | hact_end);   /* post h-active */
    mmio_w32(vp_base + 0x38u, (vact_st << 16) | vact_end);   /* post v-active */

    /* Diagnostic: a non-black VP background (green) @ DSP_BG +0x2C. If the
     * Esmart layer still fails to appear, a GREEN screen proves the VP is
     * scanning valid video to the panel — isolating a layer/framebuffer-fetch
     * problem (window enable, alpha, IOMMU) from a dead scanout. An opaque
     * full-screen layer covers this, so it only shows on failure. */
    mmio_w32(vp_base + 0x2Cu, 0x0000FF00u);

    /* Route this VP to its MIPI interface (shared system register: OR in). */
    mmio_w32(VOP2_SYS_DSP_INFACE, mmio_r32(VOP2_SYS_DSP_INFACE) | iface_bits);

    /* Leave standby, output 24-bit RGB888 (DSP_CTRL bit31=0, dsp_out_mode=0). */
    mmio_w32(vp_base + 0x00u, 0x00000000u);

    /* Latch this VP's whole config at the next frame boundary. */
    uint32_t done = (1u << 15) | (1u << cfg_done_bit);
    mmio_w32(VOP2_SYS_CFG_DONE, (done << 16) | done);

    /* Read back what actually took: DSP_CTRL bit31 should be 0 (out of
     * standby), ESMART REGION0_CTRL bit0 should be 1 (window enabled),
     * INFACE should show the mipi_out bits. A stuck standby => the commit
     * did not latch; a zero window-enable => the layer never turned on. */
    debug_write("[vop2]   rb DSP_CTRL=");
    write_hex32(mmio_r32(vp_base + 0x00u));
    debug_write(" ESMART_CTRL=");
    write_hex32(mmio_r32(esmart_base + 0x10u));
    debug_write(" INFACE=");
    write_hex32(mmio_r32(VOP2_SYS_DSP_INFACE));
    debug_write("\r\n[vop2] scanout VP + Esmart -> fb ");
    write_hex32(fb_addr);
    debug_write("\r\n");
}
/* }}} */
