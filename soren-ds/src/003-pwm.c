/*
 * 003-pwm.c — minimal PWM channel driver for the RK3568's PWM1 block
 *
 * The three indicator LEDs on the Anbernic RG DS are driven by
 * channels 5, 6, and 7 of the chip's PWM hardware. All three are
 * physically located in the PWM1 controller block at MMIO base
 * 0xFE6E0000; each channel has a 16-byte register window from the
 * block base. The mainline Linux device tree at
 * arch/arm64/boot/dts/rockchip/rk356x-base.dtsi pins the exact
 * addresses; we use them directly.
 *
 * The Rockchip PWM register window per channel (RK3568 TRM Part1 Ch15):
 *
 *   +0x00  counter  (read-only; only advances when CTRL bit 7 is set)
 *   +0x04  period   (total cycle count — PERIOD_HPR)
 *   +0x08  duty     (active-time count within a period — DUTY_LPR)
 *   +0x0C  control  (enable, mode, polarity)
 *
 * Earlier this file had +0x04 and +0x08 reversed (duty and period
 * swapped). It went unnoticed because the LED layer only ever drove
 * full duty (on) or zero duty (off), where the swap is invisible. The
 * 106c bring-up probe driving a *partial* duty exposed it — a bright
 * LED where a dim one was asked for — and the TRM confirmed the order.
 *
 * For LED on/off we only ever push the duty cycle to either the
 * full period (LED on) or zero (LED off). Brightness gradations
 * are available if a later issue ever wants them, but issue 106
 * does not.
 *
 * MMU is off at this point in phase 1 (issue 901 turns it on); on
 * aarch64 with the MMU disabled all data accesses are treated as
 * Device-nGnRnE memory by the architecture, which gives us the
 * uncached, strongly-ordered semantics MMIO needs without our
 * having to set up memory attributes ourselves. The volatile
 * qualifier on the access functions stops the compiler from
 * collapsing repeated stores.
 *
 * Clocks and pinctrl: two worlds live in this file. The plain
 * per-channel accessors (pwm_channel_setup / pwm_channel_set_duty)
 * assume the block is already clocked and the pins already routed —
 * true at u-boot handoff, where the green LED is lit (only possible
 * if PWM channel 5 already has its source clock). The bring-up path
 * (led_pwm_init, near the bottom of this file) does NOT assume that:
 * it ungates the PWM1 clock, releases the block's resets, and routes
 * the three LED pins to their PWM function itself, because the
 * SD-boot bootloader leaves the block gated and the pins on GPIO for
 * everything except the green LED. If the LEDs ever fail to respond,
 * led_pwm_init's clock-gate / reset / iomux writes are the first
 * place to check.
 */

#include <stdint.h>

/* Base addresses of the three LED-driving PWM channels. */
#define PWM_CHANNEL_5_BASE   0xFE6E0010u   /* green LED  — POWER    */
#define PWM_CHANNEL_6_BASE   0xFE6E0020u   /* amber LED  — CHARGING */
#define PWM_CHANNEL_7_BASE   0xFE6E0030u   /* red LED    — STATUS   */

/* Per-channel register offsets (RK3568 TRM Part1 Ch15: PERIOD at +0x04,
 * DUTY at +0x08 — see the header note on the swap that used to be here). */
#define PWM_PERIOD_OFFSET    0x04
#define PWM_DUTY_OFFSET      0x08
#define PWM_CONTROL_OFFSET   0x0C

/* Control register bit definitions, mirroring the values in the
 * mainline Linux driver at drivers/pwm/pwm-rockchip.c. */
#define PWM_CTRL_ENABLE             (1u << 0)
#define PWM_CTRL_CONTINUOUS         (1u << 1)
#define PWM_CTRL_DUTY_POSITIVE      (1u << 3)
#define PWM_CTRL_INACTIVE_NEGATIVE  (0u << 4)
#define PWM_CTRL_OUTPUT_LEFT        (0u << 5)

/* An arbitrary period in source-clock ticks. The actual period is
 * (this value) * (1 / source_clock_hz). Any value works for plain
 * on/off because we only drive duty to either zero or this; the
 * blink rate is set by the kernel timer if and when blink modes
 * arrive. Keeping it modest (1000) so duty arithmetic stays in
 * range. */
#define PWM_PERIOD_TICKS  1000u

/* Volatile-pointer MMIO accessors. */
static inline void mmio_write32(uintptr_t address, uint32_t value)
{
    *(volatile uint32_t *)address = value;
}

/* Configure one channel for continuous output with positive-going
 * duty and a fixed period. Duty starts at zero so the LED begins
 * off; the caller turns it on through pwm_channel_set_duty. */
static void pwm_channel_setup(uintptr_t base, uint32_t initial_duty)
{
    mmio_write32(base + PWM_PERIOD_OFFSET, PWM_PERIOD_TICKS);
    mmio_write32(base + PWM_DUTY_OFFSET, initial_duty);
    mmio_write32(base + PWM_CONTROL_OFFSET,
                 PWM_CTRL_ENABLE
                 | PWM_CTRL_CONTINUOUS
                 | PWM_CTRL_DUTY_POSITIVE
                 | PWM_CTRL_INACTIVE_NEGATIVE
                 | PWM_CTRL_OUTPUT_LEFT);
}

/* Bring up the three LED channels.
 *
 * Note that the bootloader leaves the green LED's PWM channel
 * already running with full duty (the LED is on at boot). We do
 * not need to disturb it — re-running the setup with full initial
 * duty is idempotent. The amber and red channels start with duty
 * zero, which leaves them off until the LED abstraction in
 * 004-led.c turns them on for specific boot stages. */
void pwm_init(void)
{
    pwm_channel_setup(PWM_CHANNEL_5_BASE, PWM_PERIOD_TICKS);  /* green on */
    pwm_channel_setup(PWM_CHANNEL_6_BASE, 0);                 /* amber off */
    pwm_channel_setup(PWM_CHANNEL_7_BASE, 0);                 /* red off */
}

/* Set the duty cycle on a specific channel, clamped to the period
 * so the caller cannot drive it out of range. */
void pwm_channel_set_duty(uintptr_t base, uint32_t duty)
{
    if (duty > PWM_PERIOD_TICKS) {
        duty = PWM_PERIOD_TICKS;
    }
    mmio_write32(base + PWM_DUTY_OFFSET, duty);
}

/* Resolve a channel number (5, 6, or 7) to its register base.
 * Returns zero for an unknown channel; callers should ignore
 * writes to address zero. */
uintptr_t pwm_channel_base(unsigned int channel)
{
    switch (channel) {
        case 5: return PWM_CHANNEL_5_BASE;
        case 6: return PWM_CHANNEL_6_BASE;
        case 7: return PWM_CHANNEL_7_BASE;
        default: return 0;
    }
}

/* Expose the period to the LED layer so it knows what duty value
 * means "fully on." */
uint32_t pwm_full_duty(void)
{
    return PWM_PERIOD_TICKS;
}

/* PWM LED control — brightness, and (top window only) colour.
 *
 * Three emitters in two windows (found empirically in 103e by driving
 * each pin and watching the lights):
 *   TOP    = green emitter + red emitter behind one lens (bicolor). Their
 *            blend is the colour: green only=green, red only=red, both=
 *            yellow/orange between. No blue, so no white/cyan/purple.
 *   BOTTOM = one amber emitter. Brightness only, always amber.
 *
 * Each emitter's brightness is the fraction current/max of full, written
 * to its PWM duty. That one fraction is the whole knob:
 *
 *   BRIGHTNESS : current/max IS the brightness. (3,10)=30%, (1,1)=full,
 *                (0,_)=off.
 *
 *   COLOUR (top): the RATIO of the red fraction to the green fraction is
 *                the colour; their size is the brightness.
 *                  led_top(1,1, 0,1) = full red
 *                  led_top(0,1, 1,1) = full green
 *                  led_top(1,1, 1,1) = full yellow (both full)
 *                  led_top(1,1, 1,2) = red full, green half = orange
 *
 *   SCALING MAX is how you recolour without touching 'current': since
 *                brightness = current/max, a BIGGER max makes that channel
 *                DIMMER. Doubling max_green halves green's contribution
 *                (shifts a yellow toward red); doubling max_red shifts it
 *                toward green. So to make a progress bar fill TOWARD a
 *                colour, fill 'current' normally and pre-scale each
 *                channel's 'max': e.g. max_red=total, max_green=2*total ->
 *                at 100% the bar is full red + half green = orange.
 *
 * Cost: one multiply + one divide per channel, nothing cached.
 *
 * Unlike the rest of this file, this section touches the clock gate and
 * the pin mux, because on the SD-boot path the bootloader leaves the PWM1
 * block gated and the LED pins routed to GPIO (the gap 106c covers). */
#define PWM1_CLKGATE_CON31     0xFDD2037Cu  /* bits 10,11 = PWM1 pclk/clk */
#define PWM1_SOFTRST_CON23     0xFDD2045Cu  /* bits 0,1   = PWM1 resets   */
#define PMU_GRF_GPIO0C_IOMUX_H 0xFDC20014u  /* LED pins C4/C5/C6 nibbles  */

/* current/max as a PWM duty: off when either is zero, full when
 * current >= max, the 64-bit ratio otherwise (so a large max cannot
 * overflow current*period). One multiply + one divide. */
static uint32_t led_duty(uint32_t current, uint32_t max)
{
    if (current == 0u || max == 0u) {
        return 0u;
    }
    if (current >= max) {
        return PWM_PERIOD_TICKS;
    }
    return (uint32_t)(((uint64_t)current * PWM_PERIOD_TICKS) / max);
}

/* Take the three LED pins off GPIO and onto PWM: ungate the PWM1 clock,
 * release resets, configure all three channels for continuous output at
 * zero duty, and route the pins to the PWM function. Call once before
 * led_top / led_bottom. */
void led_pwm_init(void)
{
    mmio_write32(PWM1_CLKGATE_CON31, 0x0C000000u);   /* ungate pclk + clk */
    mmio_write32(PWM1_SOFTRST_CON23, 0x00030000u);   /* release resets    */
    pwm_channel_setup(PWM_CHANNEL_5_BASE, 0);        /* green (top)    off */
    pwm_channel_setup(PWM_CHANNEL_6_BASE, 0);        /* amber (bottom) off */
    pwm_channel_setup(PWM_CHANNEL_7_BASE, 0);        /* red (top)      off */
    /* C4 (green, bits 3:0), C5 (amber, 7:4), C6 (red, 11:8) -> function 1. */
    mmio_write32(PMU_GRF_GPIO0C_IOMUX_H, 0x0FFF0111u);
}

/* Bottom amber window: brightness = current/max. */
void led_bottom(uint32_t current, uint32_t max)
{
    mmio_write32(PWM_CHANNEL_6_BASE + PWM_DUTY_OFFSET, led_duty(current, max));
}

/* Top bicolor window: red = cur_red/max_red, green = cur_green/max_green.
 * Zeros for one pair give a pure colour; two ratios blend (see the section
 * comment above on scaling max to recolour). */
void led_top(uint32_t cur_red, uint32_t max_red,
             uint32_t cur_green, uint32_t max_green)
{
    mmio_write32(PWM_CHANNEL_7_BASE + PWM_DUTY_OFFSET, led_duty(cur_red, max_red));
    mmio_write32(PWM_CHANNEL_5_BASE + PWM_DUTY_OFFSET, led_duty(cur_green, max_green));
}
