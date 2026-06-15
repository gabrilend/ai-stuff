/*
 * 004-led.c — LED abstraction and boot-stage signaling
 *
 * Three physical LEDs on the front edge of the Anbernic RG DS:
 *
 *   green   — labelled POWER in the device tree. Default on at
 *             boot, indicates the kernel exists.
 *   amber   — labelled CHARGING. Default off. We borrow it as a
 *             general "progress / activity" indicator until phase
 *             1 closes; later issues can move it back to charge
 *             status when the PMIC is wired in.
 *   red     — labelled STATUS. Default off. Reserved for panic
 *             and other "something is wrong" signals — issue 105
 *             will use it from the exception vectors.
 *
 * Each LED is driven by a PWM channel; this file sits on top of
 * the PWM driver in 003-pwm.c and exposes a higher-level vocabulary
 * matching what the rest of the kernel actually wants to say.
 *
 * The boot-stage code table the rest of the kernel uses is
 * documented in docs/015-led-diagnostic-codes.md — a developer
 * staring at the device with that table in hand can decode where
 * the kernel got stuck without any cable connected.
 */

#include <stdint.h>

/* Forward declarations of the PWM driver functions we depend on.
 * Phase 1 deliberately avoids header files so that 003 and 004 can
 * live as a self-contained pair while the kernel is small; later
 * phases will pull these into a shared include directory when there
 * are enough drivers to make that worthwhile. */
extern void pwm_init(void);
extern void pwm_channel_set_duty(uintptr_t base, uint32_t duty);
extern uintptr_t pwm_channel_base(unsigned int channel);
extern uint32_t pwm_full_duty(void);

/* The three LEDs by color, each tied to a specific PWM channel
 * per the device tree's pinctrl assignments. */
typedef enum {
    LED_GREEN = 0,
    LED_AMBER = 1,
    LED_RED   = 2,
    LED_COLOR_COUNT,
} led_color_t;

static const unsigned int led_pwm_channel[LED_COLOR_COUNT] = {
    [LED_GREEN] = 5,
    [LED_AMBER] = 6,
    [LED_RED]   = 7,
};

/* Bring the LED subsystem up. After this call, the green LED is
 * on, the amber and red LEDs are off, and the PWM channels are
 * configured to respond to subsequent led_set calls. */
void led_init(void)
{
    pwm_init();
}

/* Turn an LED hard on (full duty) or hard off (zero duty). The
 * intermediate brightness levels the PWM hardware supports are not
 * exposed here; if a later feature wants them, this is the place
 * to add a separate led_set_brightness call. */
void led_set(led_color_t color, int on)
{
    if (color >= LED_COLOR_COUNT) {
        return;
    }
    uintptr_t base = pwm_channel_base(led_pwm_channel[color]);
    if (base == 0) {
        return;
    }
    pwm_channel_set_duty(base, on ? pwm_full_duty() : 0);
}

/* Boot stages — each one is a snapshot of the kernel's state that
 * has a corresponding LED pattern in
 * docs/015-led-diagnostic-codes.md. New stages are added at the
 * end as later issues land. */
typedef enum {
    /* Kernel reached the C entry — the simplest meaningful
     * post-boot signal. Pattern: green on, amber on, red off. */
    STAGE_KERNEL_MAIN     = 0,

    /* Reserved for issue 105's panic handler. Pattern: green off,
     * amber off, red on solid. */
    STAGE_PANIC_GENERIC   = 1,

    STAGE_COUNT,
} boot_stage_t;

/* Apply the LED pattern for a stage. The full table lives in
 * docs/015-led-diagnostic-codes.md; this switch keeps the source
 * in sync with that document. Updating either side must update
 * the other, or the documentation lies. */
void led_set_stage(boot_stage_t stage)
{
    switch (stage) {
        case STAGE_KERNEL_MAIN:
            led_set(LED_GREEN, 1);
            led_set(LED_AMBER, 1);
            led_set(LED_RED,   0);
            break;

        case STAGE_PANIC_GENERIC:
            led_set(LED_GREEN, 0);
            led_set(LED_AMBER, 0);
            led_set(LED_RED,   1);
            break;

        default:
            /* Unknown stage — the caller has a bug. Light all
             * three so the developer notices something is off. */
            led_set(LED_GREEN, 1);
            led_set(LED_AMBER, 1);
            led_set(LED_RED,   1);
            break;
    }
}
