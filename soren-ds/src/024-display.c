/*
 * 024-display.c — display bring-up orchestrator (issue 111d)
 *
 * Ties the four display layers together into one call. Everything below it is
 * written and build-verified in 021 (VOP2), 022 (DSI + D-PHY), 023 (panel):
 * this file allocates the framebuffers, paints a first-light test pattern, and
 * runs the layers in order so both panels end up scanning RAM:
 *
 *   vop2_init            controller clocked, out of reset            (111a)
 *   mipi_dsi_init        both DSI hosts + D-PHYs up, PLL locked      (111b)
 *   panel_init_all       both JD9365 panels reset + DCS-initialised  (111c)
 *   dsi_enter_video_mode both hosts command -> video mode            (111d)
 *   vop2_scanout         each VP -> its framebuffer, leave standby   (111d)
 *   backlight_on         light the panels so the pixels are visible
 *
 * DORMANT: display_bringup() is not yet called from kernel_main — the boot
 * wiring is the next step, done deliberately as a unit.
 *
 * First-light residuals worth knowing (each untestable until a panel is lit):
 *  [FLAG] framebuffer must sit below 4 GiB physical (VOP2 MST is 32-bit) — we
 *    check and refuse rather than scan a truncated address.
 *  [FLAG] VOP2's IOMMU is assumed in bypass (physical addressing) at reset; if
 *    nothing shows, it may be enabled and need configuring or bypassing.
 *  [FLAG] the CPU fills the framebuffer; a dsb makes the writes reach DRAM
 *    before VOP2 reads. On this flat, no-MMU kernel memory is non-cacheable,
 *    so no cache flush is needed — revisit if the MMU/caches come on.
 *  The backlight (clock, reset, pad mux, duty, enable GPIOs) is fully wired in
 *    backlight_on(); if a lit-but-blank panel appears, the scanout path above
 *    is the suspect, not the backlight.
 */

#include <stdint.h>

extern void debug_write(const char *text);
extern uint64_t alloc_pages(uint64_t n);

extern int  vop2_init(void);
extern void vop2_scanout(uint32_t vp_base, uint32_t esmart_base,
                         uint32_t iface_bits, uint32_t cfg_done_bit,
                         uint32_t fb_addr);
extern void mipi_dsi_init(void);
extern void dsi_enter_video_mode(uint32_t dsi_base);
extern void panel_init_all(void);

static inline uint32_t mmio_r32(uint32_t a) { return *(volatile uint32_t *)(uintptr_t)a; }
static inline void mmio_w32(uint32_t a, uint32_t v) { *(volatile uint32_t *)(uintptr_t)a = v; }

static void write_hex32(uint32_t v)
{
    static const char d[] = "0123456789ABCDEF";
    char o[11]; o[0] = '0'; o[1] = 'x';
    for (int i = 0; i < 8; i++) o[2 + i] = d[(v >> ((7 - i) * 4)) & 0xF];
    o[10] = 0; debug_write(o);
}

/* 640x480, 4 bytes/pixel = 1,228,800 bytes = exactly 300 pages. */
#define FB_WIDTH   640u
#define FB_HEIGHT  480u
#define FB_BYTES   (FB_WIDTH * FB_HEIGHT * 4u)
#define FB_PAGES   ((FB_BYTES + 4095u) / 4096u)

/* {{{ static void fill_test_pattern() */
/* Eight vertical colour bars (white, yellow, cyan, green, magenta, red, blue,
 * black) in ARGB8888. An unmistakable first-light image that also exposes
 * colour order (if red and blue swap, the window needs rb_swap) and stride
 * errors (bars would shear). */
static void fill_test_pattern(uint32_t fb_addr)
{
    /* Alpha = 0xFF (opaque). ARGB8888 with alpha 0 blends transparent against
     * the VP background — a first-light black screen — so force opaque. */
    static const uint32_t bar[8] = {
        0xFFFFFFFFu, 0xFFFFFF00u, 0xFF00FFFFu, 0xFF00FF00u,
        0xFFFF00FFu, 0xFFFF0000u, 0xFF0000FFu, 0xFF000000u,
    };
    volatile uint32_t *px = (volatile uint32_t *)(uintptr_t)fb_addr;
    for (uint32_t y = 0; y < FB_HEIGHT; y++) {
        for (uint32_t x = 0; x < FB_WIDTH; x++) {
            px[y * FB_WIDTH + x] = bar[(x * 8u) / FB_WIDTH];
        }
    }
    __asm__ volatile ("dsb sy" ::: "memory");   /* writes land before VOP2 reads */
}
/* }}} */

/* {{{ void backlight_on() */
/* Light both panel backlights. They are pwm-backlights on the 0xFE700000 PWM
 * controller (channel 0 = bottom @ +0x00, channel 1 = top @ +0x10 — the same
 * controller whose channel 2 is the rumble), gated by enable lines on gpio4
 * (pins 4 and 3). Bring the controller up (clock + reset, resolved from the
 * CRU), mux the pads to PWM function, set each channel to ~80% duty, and
 * assert the enable GPIOs. Fully resolved — clock/reset, pad mux, duty, and
 * enable GPIOs are all wired. */
static void backlight_on(void)
{
    /* PWM3 controller: ungate clocks (GATE_CON32 pclk bit0/clk bit1) and
     * release reset (SOFTRST_CON23 presetn bit4/resetn bit5). Write-masked. */
    mmio_w32(0xFDD20380u, 0x00030000u);      /* clk on  */
    mmio_w32(0xFDD2045Cu, 0x00300000u);      /* reset off */

    /* Mux the PWM pads to PWM function 1: GPIO4_C5 (ch0) + GPIO4_C6 (ch1), in
     * SYS_GRF GPIO4C_IOMUX_H @ 0xFDC60074. Write-masked nibbles (C5 = bits 7:4,
     * C6 = bits 11:8). Register facts: docs/019-board-pinmux.md. */
    mmio_w32(0xFDC60074u, 0x0FF00110u);

    /* Channels 0 (bottom) and 1 (top): PERIOD +0x04, DUTY +0x08, CTRL +0x0C
     * (enable | continuous | duty-positive = 0x0B) — the 003-pwm.c layout.
     * ~80% duty = bright. */
    for (uint32_t ch = 0; ch <= 0x10u; ch += 0x10u) {
        mmio_w32(0xFE700000u + ch + 0x04u, 1000u);   /* period */
        mmio_w32(0xFE700000u + ch + 0x08u, 800u);    /* duty ~80% */
        mmio_w32(0xFE700000u + ch + 0x0Cu, 0x0Bu);   /* enable */
    }

    /* Enable GPIOs on gpio4 (base 0xFE770000): pins 4 (bottom) and 3 (top),
     * active-high. SWPORT_DDR_L @ 0x08 = output, SWPORT_DR_L @ 0x00 = high;
     * both write-masked (bit + its write-enable at bit+16). */
    for (uint32_t pin = 3u; pin <= 4u; pin++) {
        uint32_t wm = 1u << (pin + 16);
        mmio_w32(0xFE770008u, wm | (1u << pin));     /* output */
        mmio_w32(0xFE770000u, wm | (1u << pin));     /* high (enable) */
    }
    debug_write("[display] backlight on\r\n");
}
/* }}} */

/* {{{ void display_bringup() */
/* Bring both screens all the way up: allocate + paint framebuffers, run the
 * four driver layers, and light the backlights. Not wired into boot yet. */
void display_bringup(void)
{
    debug_write("\r\n[display] ===== bring-up (111a-d) =====\r\n");

    /* Boot-state snapshot BEFORE touching anything (cf. the parallel
     * display-recon probe): did u-boot/ROCKNIX leave a panel scanning? A
     * cleared POST standby bit (top bit NOT set) plus a nonzero Esmart
     * framebuffer means firmware was already driving it — the DCLK/clock tree
     * are up, and our job is to preserve that, not cold-start it. This ungates
     * the VOP clocks (ON at reset, defensive) and reads; it touches no reset,
     * so it cannot disturb whatever state firmware left. */
    mmio_w32(0xFDD20350u, 0x1FFC0000u);            /* ungate VOP2 + VO bus clks */
    debug_write("[display] boot-state POST0=");
    write_hex32(mmio_r32(0xFE040C00u));            /* VP0 DSP_CTRL (bit31 standby) */
    debug_write(" POST1=");
    write_hex32(mmio_r32(0xFE040D00u));            /* VP1 DSP_CTRL */
    debug_write(" INFACE=");
    write_hex32(mmio_r32(0xFE040028u));            /* mipi_out enables */
    debug_write(" Esmart0_fb=");
    write_hex32(mmio_r32(0xFE041814u));            /* framebuffer base (0 = none) */
    debug_write("\r\n");

    uint64_t fb0 = alloc_pages(FB_PAGES);
    uint64_t fb1 = alloc_pages(FB_PAGES);
    if (fb0 == 0 || fb1 == 0) {
        debug_write("[display] framebuffer alloc FAILED\r\n");
        return;
    }
    if ((fb0 >> 32) != 0 || (fb1 >> 32) != 0) {
        debug_write("[display] framebuffer above 4 GiB — VOP2 can't address it\r\n");
        return;
    }
    fill_test_pattern((uint32_t)fb0);
    fill_test_pattern((uint32_t)fb1);

    vop2_init();
    mipi_dsi_init();
    panel_init_all();
    dsi_enter_video_mode(0xFE060000u);       /* DSI0 (bottom) */
    dsi_enter_video_mode(0xFE070000u);       /* DSI1 (top)    */

    /* VP0 -> MIPI0 (bottom): mipi_out_en bit4, mux VP0(=0); commit bit 0.
     * VP1 -> MIPI1 (top):   mipi1_out_en bit20 + mux VP1(1<<21); commit bit 1. */
    vop2_scanout(0xFE040C00u, 0xFE041800u, 0x00000010u, 0u, (uint32_t)fb0);
    vop2_scanout(0xFE040D00u, 0xFE041A00u, 0x00300000u, 1u, (uint32_t)fb1);

    backlight_on();
    debug_write("[display] both screens scanning; fb0=");
    write_hex32((uint32_t)fb0);
    debug_write(" fb1=");
    write_hex32((uint32_t)fb1);
    debug_write("\r\n");
}
/* }}} */
