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
 * This file does not touch clocks or pinctrl. The bootloader leaves
 * the PWM1 block clocked (the green LED is on at the moment u-boot
 * hands off to us, which is only possible if PWM5 is already
 * receiving its source clock) and the iomux of all three LED pins
 * configured for their PWM functions. If the LEDs ever fail to
 * respond, the clock and iomux configuration are the first place
 * to check.
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
