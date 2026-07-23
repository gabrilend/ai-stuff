/*
 * 023-mipi-panel.c — JD9365DA-H3 panel initialization (issue 111c)
 *
 * After 022-mipi-dsi.c both DSI (Display Serial Interface) hosts sit in
 * COMMAND mode with their D-PHYs locked — able to send command packets but
 * the panels themselves are still asleep in reset, ignoring pixels. This file
 * wakes them: it pulses each panel's reset line, replays the JD9365DA-H3's
 * ~200-command DCS (Display Command Set) init table, then sends Sleep-Out and
 * Display-On. After this the panels are initialized and ready to display
 * whatever VOP2 scans at them.
 *
 * Display bring-up order: vop2_init (021) -> mipi_dsi_init (022) ->
 * panel_init (here, 111c) -> framebuffer + scanout + video-mode switch (111d)
 * -> a pixel (112). Note: the command-mode -> VIDEO-mode switch is 111d's job,
 * not this file's — it needs the panel's video timing (the porch numbers,
 * whose field order is still being confirmed), so this file leaves the panel
 * initialized but the host still in command mode.
 *
 * ---- Sourcing (all cited) -------------------------------------------------
 *  - The init table below is the panel's own DCS sequence, extracted verbatim
 *    from the board device tree's `panel_description` string (regenerate with
 *    tmp/extract-panel-seq.lua over the decompiled DTB). Not hand-typed — 203
 *    (register, value) pairs are exactly the kind of thing transcription would
 *    corrupt. The two panels' sequences are identical except ONE byte
 *    (register 0x37 in the first page: 0x09 bottom / 0x05 top), handled as a
 *    per-panel override.
 *  - DSI command FIFO (GEN_HDR @ 0x6C, CMD_PKT_STATUS @ 0x74 gen_cmd_full=bit1)
 *    and CMD_MODE_CFG @ 0x68 low-power bits: TRM Part2 Ch29 — verified.
 *  - GPIO output regs (GPIO0 @ 0xFDD60000, SWPORT_DR_L @ 0x00, SWPORT_DDR_L @
 *    0x08, write-masked): TRM Part1 Ch16 — verified. Reset pins from the DTB
 *    (GPIO0_B3 = pin 11 bottom, GPIO0_B4 = pin 12 top, active-low).
 *  [ASSUME] The (register,value) pairs go out as DCS Short Write, 1 parameter
 *    (data type 0x15) — the mainline JD9365 driver's convention. If the panel
 *    ignores them, the alternative is Generic Short Write, 2 params (0x23);
 *    CMD_MODE_CFG below already enables low-power for both, so it is a
 *    one-constant change.
 */

#include <stdint.h>

extern void debug_write(const char *text);

/* {{{ mmio + delay helpers */
static inline uint32_t mmio_r32(uint32_t a) { return *(volatile uint32_t *)(uintptr_t)a; }
static inline void mmio_w32(uint32_t a, uint32_t v) { *(volatile uint32_t *)(uintptr_t)a = v; }
static void busy_delay(uint32_t n) { for (volatile uint32_t i = 0; i < n; i++) { } }
/* Rough millisecond wait — the loop count that felt like ~1 ms elsewhere in
 * the bring-up code; panel reset/settle times are generous, exactness is not
 * required (JD9365 wants ~10 ms reset low, ~120 ms after Sleep-Out). */
#define MS(n) busy_delay((n) * 30000u)
/* }}} */

/* ---- GPIO0 panel-reset line (TRM Part1 Ch16, write-masked) --------------- */
#define GPIO0_BASE        0xFDD60000u
#define GPIO0_SWPORT_DR_L  0x00u   /* data,      pins 0..15 */
#define GPIO0_SWPORT_DDR_L 0x08u   /* direction, pins 0..15 (1 = output)      */

/* {{{ static void panel_reset_pulse() */
/* Drive one panel's active-low reset: make the pin an output, hold it high,
 * pull low ~10 ms, release high, then wait for the panel to come out of reset.
 * pin is a GPIO0 bit in the low half (bottom = 11, top = 12). */
static void panel_reset_pulse(uint32_t pin)
{
    uint32_t wmask = 1u << (pin + 16);                 /* write-enable this bit  */
    mmio_w32(GPIO0_BASE + GPIO0_SWPORT_DDR_L, wmask | (1u << pin)); /* output    */
    mmio_w32(GPIO0_BASE + GPIO0_SWPORT_DR_L,  wmask | (1u << pin)); /* high      */
    MS(5);
    mmio_w32(GPIO0_BASE + GPIO0_SWPORT_DR_L,  wmask);              /* low: reset */
    MS(10);
    mmio_w32(GPIO0_BASE + GPIO0_SWPORT_DR_L,  wmask | (1u << pin)); /* release   */
    MS(120);
}
/* }}} */

/* ---- DSI host command send (TRM Part2 Ch29) ----------------------------- */
#define DSI_CMD_MODE_CFG   0x68u   /* per-command-type LP/HS select            */
#define DSI_GEN_HDR        0x6Cu   /* header write triggers a short packet TX  */
#define DSI_CMD_PKT_STATUS 0x74u   /* bit1 gen_cmd_full                        */
#define DSI_GEN_CMD_FULL   (1u << 1)
/* All command types in low-power mode (bits 8..19,24) — init MUST go LP. */
#define DSI_CMD_MODE_ALL_LP 0x010F7F00u
/* MIPI data types. */
#define DT_DCS_SW_1P       0x15u   /* DCS short write, 1 param  (reg,val)      */
#define DT_DCS_SW_0P       0x05u   /* DCS short write, 0 param  (sleep/display) */
#define DCS_SLEEP_OUT      0x11u
#define DCS_DISPLAY_ON     0x29u

/* {{{ static void dsi_short() */
/* Send one short DSI packet: wait for the generic-command FIFO to have room,
 * then write GEN_HDR = data_type | data0<<8 | data1<<16 (TRM Ch29 GEN_HDR). */
static void dsi_short(uint32_t dsi_base, uint32_t dt, uint32_t d0, uint32_t d1)
{
    uint32_t t = 100000u;
    while (t-- && (mmio_r32(dsi_base + DSI_CMD_PKT_STATUS) & DSI_GEN_CMD_FULL)) {
        busy_delay(8u);
    }
    mmio_w32(dsi_base + DSI_GEN_HDR, dt | (d0 << 8) | (d1 << 16));
}
/* }}} */

/* JD9365DA-H3 init table — (register, value) DCS pairs, extracted from the
 * board DTB panel_description (see the header note; regenerate, do not edit by
 * hand). 203 entries; entry 18 (register 0x37) is overridden per panel. */
static const uint8_t jd9365_init[][2] = {
    {0xe0,0x00},{0xe1,0x93},{0xe2,0x65},{0xe3,0xf8},{0x80,0x03},{0xe0,0x01},
    {0x00,0x00},{0x01,0x6a},{0x03,0x10},{0x04,0x6a},{0x0c,0x74},{0x17,0x00},
    {0x18,0xbf},{0x19,0x01},{0x1a,0x00},{0x1b,0xbf},{0x1c,0x01},{0x24,0xfe},
    {0x37,0x09},{0x38,0x02},{0x39,0x08},{0x3a,0x1f},{0x3c,0xf7},{0x3d,0xff},
    {0x3e,0xff},{0x3f,0xff},{0x40,0x03},{0x41,0x3c},{0x42,0xff},{0x43,0x0a},
    {0x44,0x11},{0x45,0x78},{0x55,0x02},{0x57,0x6d},{0x58,0x0a},{0x59,0x0a},
    {0x5a,0x1f},{0x5b,0x1f},{0x5d,0x7f},{0x5e,0x56},{0x5f,0x43},{0x60,0x34},
    {0x61,0x2f},{0x62,0x20},{0x63,0x22},{0x64,0x0c},{0x65,0x24},{0x66,0x24},
    {0x67,0x25},{0x68,0x43},{0x69,0x33},{0x6a,0x3a},{0x6b,0x2d},{0x6c,0x28},
    {0x6d,0x1b},{0x6e,0x0b},{0x6f,0x00},{0x70,0x7f},{0x71,0x56},{0x72,0x43},
    {0x73,0x34},{0x74,0x2f},{0x75,0x20},{0x76,0x22},{0x77,0x0c},{0x78,0x24},
    {0x79,0x24},{0x7a,0x25},{0x7b,0x43},{0x7c,0x33},{0x7d,0x3a},{0x7e,0x2d},
    {0x7f,0x28},{0x80,0x1b},{0x81,0x0b},{0x82,0x00},{0xe0,0x02},{0x00,0x5f},
    {0x01,0x5f},{0x02,0x5f},{0x03,0x5e},{0x04,0x50},{0x05,0x40},{0x06,0x5f},
    {0x07,0x57},{0x08,0x77},{0x09,0x48},{0x0a,0x48},{0x0b,0x4a},{0x0c,0x4a},
    {0x0d,0x44},{0x0e,0x44},{0x0f,0x46},{0x10,0x46},{0x11,0x5f},{0x12,0x5f},
    {0x13,0x5f},{0x14,0x5f},{0x15,0x5f},{0x16,0x5f},{0x17,0x5f},{0x18,0x5f},
    {0x19,0x5e},{0x1a,0x50},{0x1b,0x41},{0x1c,0x5f},{0x1d,0x57},{0x1e,0x77},
    {0x1f,0x49},{0x20,0x49},{0x21,0x4b},{0x22,0x4b},{0x23,0x45},{0x24,0x45},
    {0x25,0x47},{0x26,0x47},{0x27,0x5f},{0x28,0x5f},{0x29,0x5f},{0x2a,0x5f},
    {0x2b,0x5f},{0x2c,0x1f},{0x2d,0x1f},{0x2e,0x1e},{0x2f,0x1f},{0x30,0x10},
    {0x31,0x01},{0x32,0x1f},{0x33,0x17},{0x34,0x17},{0x35,0x07},{0x36,0x07},
    {0x37,0x05},{0x38,0x05},{0x39,0x0b},{0x3a,0x0b},{0x3b,0x09},{0x3c,0x09},
    {0x3d,0x1f},{0x3e,0x1f},{0x3f,0x1f},{0x40,0x1f},{0x41,0x1f},{0x42,0x1f},
    {0x43,0x1f},{0x44,0x1e},{0x45,0x1f},{0x46,0x10},{0x47,0x00},{0x48,0x1f},
    {0x49,0x17},{0x4a,0x17},{0x4b,0x06},{0x4c,0x06},{0x4d,0x04},{0x4e,0x04},
    {0x4f,0x0a},{0x50,0x0a},{0x51,0x08},{0x52,0x08},{0x53,0x1f},{0x54,0x1f},
    {0x55,0x1f},{0x56,0x1f},{0x57,0x1f},{0x58,0x40},{0x59,0x00},{0x5a,0x00},
    {0x5b,0x10},{0x5c,0x07},{0x5d,0x30},{0x5e,0x01},{0x5f,0x02},{0x60,0x30},
    {0x61,0x01},{0x62,0x02},{0x63,0x06},{0x64,0xe9},{0x65,0x40},{0x66,0x02},
    {0x67,0x73},{0x68,0x0b},{0x69,0x06},{0x6a,0xe9},{0x6b,0x08},{0x75,0xda},
    {0x76,0x00},{0x77,0x01},{0x78,0xfc},{0x81,0x08},{0x83,0xf4},{0x87,0x10},
    {0xe0,0x04},{0x00,0x0e},{0x02,0xb3},{0x09,0x60},{0x0e,0x48},{0x1e,0x00},
    {0x37,0x58},{0x2b,0x0f},{0xe0,0x05},{0x15,0x1d},{0xe0,0x00},
};
#define JD9365_INIT_COUNT ((int)(sizeof(jd9365_init) / sizeof(jd9365_init[0])))
#define JD9365_REG37_INDEX 18    /* the one command that differs per panel     */

/* One screen's panel: its DSI host, its reset pin, and its register-0x37 byte. */
struct panel_instance {
    const char *name;
    uint32_t    dsi_base;
    uint32_t    reset_pin;   /* GPIO0 low-half bit                             */
    uint8_t     reg37_val;   /* 0x09 bottom / 0x05 top (the lone per-panel diff) */
};

static const struct panel_instance panel_bottom = { "bottom", 0xFE060000u, 11u, 0x09u };
static const struct panel_instance panel_top    = { "top",    0xFE070000u, 12u, 0x05u };

/* {{{ static void panel_init() */
/* Reset one panel, replay its DCS init table in low-power mode, then Sleep-Out
 * and Display-On. Leaves the panel initialized; the host stays in command mode
 * until 111d configures video timing and switches it. */
static void panel_init(const struct panel_instance *p)
{
    debug_write("\r\n[panel] init "); debug_write(p->name); debug_write("\r\n");

    panel_reset_pulse(p->reset_pin);

    /* All command types low-power for the init burst (TRM Ch29 CMD_MODE_CFG). */
    mmio_w32(p->dsi_base + DSI_CMD_MODE_CFG, DSI_CMD_MODE_ALL_LP);

    /* Replay the JD9365 register table, overriding the one per-panel byte. */
    for (int i = 0; i < JD9365_INIT_COUNT; i++) {
        uint8_t reg = jd9365_init[i][0];
        uint8_t val = (i == JD9365_REG37_INDEX) ? p->reg37_val : jd9365_init[i][1];
        dsi_short(p->dsi_base, DT_DCS_SW_1P, reg, val);
    }
    debug_write("[panel]   init table sent\r\n");

    /* Wake the panel: Sleep-Out (needs up to 120 ms before more traffic),
     * then Display-On. */
    dsi_short(p->dsi_base, DT_DCS_SW_0P, DCS_SLEEP_OUT, 0u);
    MS(120);
    dsi_short(p->dsi_base, DT_DCS_SW_0P, DCS_DISPLAY_ON, 0u);
    MS(20);
    debug_write("[panel]   sleep-out + display-on — panel ready (video mode: 111d)\r\n");
}
/* }}} */

/* {{{ void panel_init_all() */
/* Initialize both panels (issue 111c). Written and compile-verified but NOT
 * wired into boot yet — the display path is switched on as a whole once 111d
 * adds framebuffers and the video-mode switch. */
void panel_init_all(void)
{
    debug_write("\r\n[panel] ===== JD9365 panel init (111c) =====\r\n");
    panel_init(&panel_bottom);
    panel_init(&panel_top);
    debug_write("[panel] both panels initialized\r\n");
}
/* }}} */
