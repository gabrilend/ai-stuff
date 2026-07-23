/*
 * 022-mipi-dsi.c — MIPI DSI host + TX D-PHY bring-up (issue 111b)
 *
 * VOP2 (021-vop2.c) produces a parallel pixel stream; it cannot travel down
 * the thin ribbon to a panel. The MIPI DSI (Display Serial Interface) host
 * serializes that stream into packets, and the MIPI TX D-PHY (the physical
 * layer — the "D" is the Roman numeral 500, its original Mbps target) is the
 * analog transmitter that drives the bits onto the wire pairs (lanes). This
 * file brings both up, for both screens, to the point where the DSI host sits
 * in COMMAND mode with the D-PHY's PLL (Phase-Locked Loop — the clock
 * multiplier) locked and the lanes idle — ready for 111c to send the panel
 * its wake-up sequence.
 *
 * Two identical instances: DSI0 (0xFE060000) + D-PHY0 (0xFE850000) drive the
 * BOTTOM panel via VOP2 VP0; DSI1 (0xFE070000) + D-PHY1 (0xFE860000) drive the
 * TOP via VP1. One function, parameterized on the instance, runs twice.
 *
 * Display bring-up order: vop2_init (021, done) -> mipi_dsi_init (here) ->
 * panel init (111c) -> framebuffer + scanout (111d) -> a pixel (112).
 *
 * ---- Sourcing (every value cited; this block writes real hardware) --------
 * All register values are derived from the RK3568 TRM, cross-checked against
 * the board device tree and (where the TRM is thin) the Rockchip Linux
 * drivers. Confidence is called out inline. The genuinely load-bearing facts
 * are TRM-verified:
 *   - CRU gate/reset bits: TRM Part1 CRU register tables (CRU_GATE_CON21/33,
 *     CRU_SOFTRST_CON17/27) — verified bit-for-bit.
 *   - D-PHY register map + the MIPI-mode init sequence + the PLL formula:
 *     TRM Part2 Ch30 §30.3/§30.4 — verified.
 *   - DSI host PWR_UP / PHY_STATUS(lock=bit0, clk-lane-stopstate=bit2) /
 *     PHY_IF_CFG n_lanes: TRM Part2 Ch29 — verified. The DSI host is a
 *     Synopsys DW-MIPI-DSI, a standard IP.
 *
 * Three choices the public TRM does NOT state outright — flagged loudly so a
 * hardware run knows where to look if a panel stays dark:
 *   [ASSUME-1] D-PHY register STRIDE = base + (index << 2), 32-bit writes.
 *     The TRM lists byte indices (0x00,0x01,0x03,…) under an "internal
 *     address mapping / slave address / APB" note; the Rockchip inno-DSI-DPHY
 *     driver accesses them word-strided. If the PLL never locks, the stride is
 *     the first thing to re-check.
 *   [ASSUME-2] PLL dividers for OUR panel: target ~324 Mbps/lane and the exact
 *     dividers — see the PLL section. The formula + sequence are TRM-verified;
 *     only the divider TRIPLE is computed (tunable on hardware).
 *   [ASSUME-3] The DSI/D-PHY parent clocks (pclk_vo, pclk_top) are left as
 *     found — they power much of the VO domain and read ON at boot (as VOP2's
 *     did). We ungate the leaf clocks; if a parent were gated, add it here.
 * The GRF VO_CON lane-control regs (BSP-only, not in the TRM) are left at
 * reset: MIPI mode is the D-PHY's power-on default (LVDS_REG03=0x01), so a
 * minimal MIPI TX bring-up needs no GRF write.
 */

#include <stdint.h>

extern void debug_write(const char *text);

/* {{{ mmio + narration helpers */
static inline uint32_t mmio_r32(uint32_t a) { return *(volatile uint32_t *)(uintptr_t)a; }
static inline void mmio_w32(uint32_t a, uint32_t v) { *(volatile uint32_t *)(uintptr_t)a = v; }

static void busy_delay(uint32_t n)
{
    for (volatile uint32_t i = 0; i < n; i++) { /* the read/write of i is the wait */ }
}

static void write_hex32(uint32_t v)
{
    static const char digits[] = "0123456789ABCDEF";
    char out[11];
    out[0] = '0'; out[1] = 'x';
    for (int i = 0; i < 8; i++) out[2 + i] = digits[(v >> ((7 - i) * 4)) & 0xF];
    out[10] = 0;
    debug_write(out);
}
/* }}} */

/* ---- CRU: clock-gate + soft-reset (TRM Part1 CRU, verified) --------------
 * Write-mask registers: to change bit B write ((1<<(B+16)) | (value<<B)).
 * A gate bit 0 = clock ENABLED; a reset bit 0 = reset RELEASED. Addresses:
 * CRU_GATE_CON<n> = 0xFDD20300 + 4n; CRU_SOFTRST_CON<n> = 0xFDD20400 + 4n. */
#define CRU_GATE_CON21     0xFDD20354u   /* pclk_dsitx_0 (bit6) / _1 (bit7)      */
#define CRU_GATE_CON33     0xFDD20384u   /* pclk_mipidsiphy0 (b14) / 1 (b15)     */
#define CRU_SOFTRST_CON17  0xFDD20444u   /* presetn_dsitx_0 (b0) / _1 (b1)       */
#define CRU_SOFTRST_CON27  0xFDD2046Cu   /* presetn_mipidsiphy0 (b11) / 1 (b12)  */

/* ---- DSI host (Synopsys DW-MIPI-DSI, TRM Part2 Ch29) register offsets ----
 * These are normal word-aligned MMIO offsets from the host base. */
#define DSI_PWR_UP       0x04u   /* bit0 shutdownz: 0=reset, 1=powered            */
#define DSI_CLKMGR_CFG   0x08u   /* [7:0] tx_esc_clk_div, [15:8] to_clk_div       */
#define DSI_MODE_CFG     0x34u   /* bit0 cmd_video_mode: 1=command, 0=video        */
#define DSI_PHY_RSTZ     0xA0u   /* b3 forcepll b2 enableclk b1 rstz b0 shutdownz  */
#define DSI_PHY_IF_CFG   0xA4u   /* [1:0] n_lanes = lanes-1                         */
#define DSI_PHY_STATUS   0xB0u   /* bit0 phy_lock, bit2 phy_stopstateclklane        */

#define DSI_N_LANES_4        0x3u          /* PHY_IF_CFG[1:0] = lanes-1 = 3 for 4    */
#define DSI_PHY_RSTZ_RELEASE 0xFu          /* forcepll|enableclk|rstz|shutdownz      */
#define DSI_PHY_LOCK         (1u << 0)
#define DSI_PHY_STOPSTATE_CLK (1u << 2)
/* Escape clock must be <= ~20 MHz. At ~324 Mbps the lane-byte clock is
 * ~40.5 MHz, so tx_esc_clk_division = 4 gives ~10 MHz. to_clk_division = 10 is
 * the timeout counter base. [tunable — matters for LP command TX in 111c] */
#define DSI_CLKMGR_VALUE     ((10u << 8) | 4u)

/* ---- MIPI TX D-PHY (inno, TRM Part2 Ch30) --------------------------------
 * Register INDICES (accessed at dphy_base + (index<<2) — see [ASSUME-1]).
 * The MIPI-mode init sequence and every value below is TRM §30.4.1 verbatim,
 * except PLL_FBDIV which we retune for our pixel clock (see the PLL section). */
#define DPHY_ANALOG_REG00  0x00u  /* power + lane enable                            */
#define DPHY_ANALOG_REG01  0x01u  /* PLL/LDO power, analog sync reset               */
#define DPHY_ANALOG_REG03  0x03u  /* [4:0] pll_prediv, [5] fbdiv_msb                */
#define DPHY_ANALOG_REG04  0x04u  /* [7:0] pll_fbdiv                                */
#define DPHY_ANALOG_REG08  0x08u  /* PLL post-divider enable + Vod                  */
#define DPHY_DIGITAL_REG00 0x20u  /* bit0 dig_rstn: 0=reset, 1=normal              */

/* PLL math (TRM §30.4.3):  PLL_OUTPUT = (24MHz / PREDIV) * FBDIV / POSTDIV,
 * where PLL_OUTPUT (MHz) == the lane bit rate (Mbps), and POSTDIV = 2 iff the
 * postdiv register bit is set, else 1.
 *
 * [ASSUME-2] Target lane rate. The Rockchip DSI glue requests
 *   ceil(pixel_kHz/1000) * bpp/lanes * 10/8 = ceil(42134/1000)*24/4*10/8
 *   = 43 * 6 * 1.25 = 322.5 Mbps/lane  (the ×10/8 is the driver's standing
 *   headroom over raw RGB bandwidth). Solve with PREDIV=2, POSTDIV=1 (disabled):
 *     FBDIV = 322.5 / (24/2) = 26.9 -> 27  ->  PLL_OUTPUT = 12*27 = 324 Mbps.
 * So: PREDIV=2 (REG03=0x02), FBDIV=27 (REG04=0x1B, fbdiv_msb=0), POSTDIV off
 * (REG08=0x4E). TRM's own example is FBDIV=0x53 (996 Mbps) — we swap only the
 * FBDIV byte for our slower panel. If the PLL will not lock at this ~324 MHz
 * VCO, the fallback with the same output is POSTDIV=2 + FBDIV=54 (VCO 648). */
#define DPHY_PREDIV_VAL      0x02u        /* PREDIV = 2                            */
#define DPHY_FBDIV_VAL       0x1Bu        /* FBDIV  = 27  -> ~324 Mbps/lane        */
#define DPHY_POSTDIV_OFF     0x4Eu        /* postdiv disabled (POSTDIV = 1)        */
#define DPHY_REG01_PLL_LDO   0xE4u        /* enable PLL+LDO, analog sync-reset held */
#define DPHY_REG01_RUN       0xE0u        /* release analog sync-reset             */
#define DPHY_REG00_LANES_ON  0x7Du        /* clk+lane0..3 en, power-work, bandgap on */
#define DPHY_DIG_RESET       0x1Eu        /* dig_rstn = 0 (assert)                 */
#define DPHY_DIG_NORMAL      0x1Fu        /* dig_rstn = 1 (release)                */

/* One screen's controller + PHY + its CRU write-masks. */
struct dsi_instance {
    const char *name;
    uint32_t dsi_base;
    uint32_t dphy_base;
    uint32_t dsi_gate;     /* CRU_GATE_CON21    write-mask (pclk_dsitx_n on)      */
    uint32_t dphy_gate;    /* CRU_GATE_CON33    write-mask (pclk_mipidsiphy_n on) */
    uint32_t dsi_reset;    /* CRU_SOFTRST_CON17 write-mask (presetn_dsitx_n rel.) */
    uint32_t dphy_reset;   /* CRU_SOFTRST_CON27 write-mask (presetn_mipidsiphy_n) */
};

static const struct dsi_instance dsi0 = {
    "DSI0/bottom", 0xFE060000u, 0xFE850000u,
    0x00400000u, 0x40000000u, 0x00010000u, 0x08000000u,   /* bits 6 / 14 / 0 / 11 */
};
static const struct dsi_instance dsi1 = {
    "DSI1/top", 0xFE070000u, 0xFE860000u,
    0x00800000u, 0x80000000u, 0x00020000u, 0x10000000u,   /* bits 7 / 15 / 1 / 12 */
};

/* {{{ static void dphy_w() */
/* Write one inno D-PHY register by its TRM index. [ASSUME-1]: the byte index
 * is placed on the word-strided APB, so the address is base + (index<<2). */
static void dphy_w(uint32_t dphy_base, uint32_t index, uint32_t val)
{
    mmio_w32(dphy_base + (index << 2), val);
}
/* }}} */

/* {{{ static void dphy_pll_bringup() */
/* Bring one MIPI TX D-PHY up in MIPI mode with its PLL locked and 4 lanes
 * enabled — TRM §30.4.1, with our FBDIV. Leaves the PLL running; the DSI host
 * observes lock via its PHY_STATUS after it releases PHY_RSTZ. */
static void dphy_pll_bringup(uint32_t dphy_base)
{
    dphy_w(dphy_base, DPHY_ANALOG_REG03, DPHY_PREDIV_VAL);   /* PLL PREDIV = 2     */
    dphy_w(dphy_base, DPHY_ANALOG_REG04, DPHY_FBDIV_VAL);    /* PLL FBDIV  = 27    */
    dphy_w(dphy_base, DPHY_ANALOG_REG08, DPHY_POSTDIV_OFF);  /* POSTDIV disabled   */
    dphy_w(dphy_base, DPHY_ANALOG_REG01, DPHY_REG01_PLL_LDO);/* PLL+LDO on, rst held */
    dphy_w(dphy_base, DPHY_ANALOG_REG00, DPHY_REG00_LANES_ON);/* clk+4 lanes, bandgap */
    dphy_w(dphy_base, DPHY_ANALOG_REG01, DPHY_REG01_RUN);    /* release analog reset */
    busy_delay(20000u);
    dphy_w(dphy_base, DPHY_DIGITAL_REG00, DPHY_DIG_RESET);   /* digital reset assert */
    dphy_w(dphy_base, DPHY_DIGITAL_REG00, DPHY_DIG_NORMAL);  /* digital reset release */
    busy_delay(20000u);
}
/* }}} */

/* {{{ static int dsi_dphy_bringup() */
/* Bring one screen's DSI host + D-PHY up to COMMAND mode with the PLL locked.
 * Returns 0 on lock, -1 on timeout. Narrates each step so a hardware run pins
 * the failing stage. */
static int dsi_dphy_bringup(const struct dsi_instance *d)
{
    debug_write("\r\n[dsi] bring-up "); debug_write(d->name); debug_write("\r\n");

    /* 1. CRU: ungate the DSI-host + D-PHY leaf clocks, release their resets.
     *    Parent clocks (pclk_vo, pclk_top) assumed ON at boot — see [ASSUME-3]. */
    mmio_w32(CRU_GATE_CON21, d->dsi_gate);
    mmio_w32(CRU_GATE_CON33, d->dphy_gate);
    mmio_w32(CRU_SOFTRST_CON17, d->dsi_reset);
    mmio_w32(CRU_SOFTRST_CON27, d->dphy_reset);
    busy_delay(10000u);

    /* 2. Hold the DSI host in reset, hold its PHY interface in reset, and set
     *    the escape-clock divider + lane count before the PHY comes up. */
    mmio_w32(d->dsi_base + DSI_PWR_UP, 0u);            /* host held in reset       */
    mmio_w32(d->dsi_base + DSI_PHY_RSTZ, 0u);          /* phy shutdownz+rstz = 0   */
    mmio_w32(d->dsi_base + DSI_CLKMGR_CFG, DSI_CLKMGR_VALUE);
    mmio_w32(d->dsi_base + DSI_PHY_IF_CFG, DSI_N_LANES_4);  /* 4 data lanes         */

    /* 3. Bring the D-PHY analog up (TRM §30.4.1): PLL dividers, power, lanes,
     *    digital reset toggle. The PLL starts locking here. */
    debug_write("[dsi]   D-PHY PLL + lanes (TRM 30.4.1, ~324 Mbps/lane)\r\n");
    dphy_pll_bringup(d->dphy_base);

    /* 4. Release the DSI host's PHY interface so it drives the now-running PHY. */
    mmio_w32(d->dsi_base + DSI_PHY_RSTZ, DSI_PHY_RSTZ_RELEASE);

    /* 5. Poll PHY_STATUS for PLL lock + clock-lane stop-state (TRM Ch29). */
    uint32_t tries = 100000u, st = 0u;
    while (tries--) {
        st = mmio_r32(d->dsi_base + DSI_PHY_STATUS);
        if ((st & (DSI_PHY_LOCK | DSI_PHY_STOPSTATE_CLK))
            == (DSI_PHY_LOCK | DSI_PHY_STOPSTATE_CLK)) {
            break;
        }
        busy_delay(64u);
    }
    debug_write("[dsi]   PHY_STATUS = "); write_hex32(st);
    if ((st & DSI_PHY_LOCK) == 0u) {
        debug_write("  PLL NOT LOCKED — check D-PHY stride/dividers\r\n");
        return -1;
    }
    debug_write((st & DSI_PHY_STOPSTATE_CLK) ? "  locked + stopstate\r\n"
                                             : "  locked (no clk-lane stopstate yet)\r\n");

    /* 6. Enter COMMAND mode and power the host up — ready for 111c panel init. */
    mmio_w32(d->dsi_base + DSI_MODE_CFG, 1u);          /* command mode              */
    mmio_w32(d->dsi_base + DSI_PWR_UP, 1u);            /* power up                  */
    debug_write("[dsi]   command mode — ready for panel init (111c)\r\n");
    return 0;
}
/* }}} */

/* {{{ void mipi_dsi_init() */
/* Bring up both screens' DSI + D-PHY (issue 111b). Written and ready, but NOT
 * wired into kernel_main yet — the display path becomes useful only once the
 * panel init (111c) and scanout (111d) land, so the whole sequence is wired in
 * together, later and deliberately (as vop2_init in 021 is). */
void mipi_dsi_init(void)
{
    debug_write("\r\n[dsi] ===== MIPI DSI + D-PHY bring-up (111b) =====\r\n");
    int a = dsi_dphy_bringup(&dsi0);
    int b = dsi_dphy_bringup(&dsi1);
    debug_write((a == 0 && b == 0) ? "[dsi] both links up\r\n"
              : (a == 0 || b == 0) ? "[dsi] one link up, one failed\r\n"
              :                      "[dsi] both links FAILED to lock\r\n");
}
/* }}} */

/* ---- DSI command -> video mode switch (issue 111d) ----------------------
 * Program the panel's video timing and flip the host from command mode (used
 * for the 111c init burst) to continuous video-mode streaming. Offsets are
 * TRM Ch29 (verified): DPI_COLOR_CODING 0x10, MODE_CFG 0x34, VID_MODE_CFG
 * 0x38, VID_PKT_SIZE 0x3C, VID_HSA_TIME 0x48, VID_HBP_TIME 0x4C,
 * VID_HLINE_TIME 0x50, VID_VSA_LINES 0x54, VID_VBP_LINES 0x58, VID_VFP_LINES
 * 0x5C, VID_VACTIVE_LINES 0x60, LPCLK_CTRL 0x94.
 *
 * The HORIZONTAL timings are in lane-byte-clock cycles, not pixels: scale a
 * pixel count by lane_byte_clk / pixel_clk. lane_byte_clk = lane_rate/8 =
 * ~324 Mbps / 8 = ~40.5 MHz; pixel clock 42.134 MHz. [FLAG] this factor rides
 * on the flagged ~324 Mbps PLL rate from the D-PHY bring-up — if the image is
 * horizontally stretched/compressed or the panel won't lock, the PLL dividers
 * (above) and this factor are where to look. Vertical timings are in lines. */
#define VID_LANE_BYTE_KHZ 40500u    /* ~324 Mbps / 8                          */
#define VID_PIXEL_KHZ     42134u    /* panel pixel clock (from the DTB)       */
#define P_HACT  640u
#define P_HFP   260u
#define P_HSYNC 220u
#define P_HBP   260u
#define P_VACT  480u
#define P_VFP    10u
#define P_VSYNC   2u
#define P_VBP    16u

/* {{{ static uint32_t dsi_lbcc() */
/* Pixels -> lane-byte-clock cycles. (pixels * 40500) stays well under 2^32
 * for any timing here, so plain 32-bit integer math is exact enough. */
static uint32_t dsi_lbcc(uint32_t pixels)
{
    return (pixels * VID_LANE_BYTE_KHZ) / VID_PIXEL_KHZ;
}
/* }}} */

/* {{{ void dsi_enter_video_mode() */
/* Switch one DSI host from command to video mode with the panel timing.
 * Every MODE_CFG change is bracketed by PWR_UP low then high — the DW rule. */
void dsi_enter_video_mode(uint32_t dsi_base)
{
    uint32_t htotal = P_HACT + P_HFP + P_HSYNC + P_HBP;

    mmio_w32(dsi_base + 0x04u, 0u);                 /* PWR_UP = reset while reconfig */

    mmio_w32(dsi_base + 0x10u, 0x05u);             /* DPI_COLOR_CODING = 24-bit RGB */
    mmio_w32(dsi_base + 0x3Cu, P_HACT);            /* VID_PKT_SIZE (pixels/line)    */
    mmio_w32(dsi_base + 0x48u, dsi_lbcc(P_HSYNC)); /* VID_HSA_TIME                  */
    mmio_w32(dsi_base + 0x4Cu, dsi_lbcc(P_HBP));   /* VID_HBP_TIME                  */
    mmio_w32(dsi_base + 0x50u, dsi_lbcc(htotal));  /* VID_HLINE_TIME                */
    mmio_w32(dsi_base + 0x54u, P_VSYNC);           /* VID_VSA_LINES                 */
    mmio_w32(dsi_base + 0x58u, P_VBP);             /* VID_VBP_LINES                 */
    mmio_w32(dsi_base + 0x5Cu, P_VFP);             /* VID_VFP_LINES                 */
    mmio_w32(dsi_base + 0x60u, P_VACT);            /* VID_VACTIVE_LINES             */
    mmio_w32(dsi_base + 0x38u, 0x00003F02u);       /* VID_MODE_CFG: LP blanking + burst */

    mmio_w32(dsi_base + 0x34u, 0u);                /* MODE_CFG = video (bit0 = 0)   */
    mmio_w32(dsi_base + 0x94u, 0x01u);             /* LPCLK_CTRL: request HS clock  */
    mmio_w32(dsi_base + 0x04u, 1u);                /* PWR_UP = on                   */

    debug_write("[dsi] video mode @ ");
    write_hex32(dsi_base);
    debug_write("\r\n");
}
/* }}} */
