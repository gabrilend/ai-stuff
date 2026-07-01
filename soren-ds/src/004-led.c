/*
 * 004-led.c — LED abstraction and boot-stage signaling, via PWM
 *
 * Two physical lights on the front edge of the Anbernic RG DS:
 *
 *   top window     A bicolor LED with separate green and red
 *                  emitters behind one diffuser. Driving the
 *                  green-named channel lights the green emitter;
 *                  driving the red-named channel lights the red
 *                  emitter; driving both at once additively mixes
 *                  to a yellow-amber appearance brighter than
 *                  either alone.
 *
 *   bottom window  A single-color amber LED, driven by the
 *                  amber-named channel.
 *
 * The names green / amber / red describe the *channels/pins* the
 * layer's primitives accept, not the *physical lights* a user sees.
 * The mapping from channel names to visible patterns is documented
 * in docs/015-led-diagnostic-codes.md alongside the boot-stage
 * table that drives this file.
 *
 * Mechanism: this layer drives the three LED pins through the PWM1
 * controller's duty-cycle hardware (src/003-pwm.c), not the GPIO
 * controller. led_init calls led_pwm_init, which ungates the PWM1
 * clock, releases its resets, and routes the pins to their PWM
 * function; led_set writes full or zero duty for on/off; the
 * heartbeat steps the amber channel's duty for a smooth breathing
 * fade during long operations.
 *
 * Why PWM and not GPIO: an earlier pivot (issue 106b) drove these
 * pins through the always-on GPIO0 controller, which needs no clock
 * or reset setup and so is the most robust possible earliest-boot
 * signal — it cannot be broken by a clocking mistake. Issue 106c
 * then brought the PWM controller up and proved it on hardware, and
 * this layer moved onto it to regain graded brightness: the
 * breathing heartbeat from 106a and the top window's colour blend.
 * The one thing traded away is that PWM depends on the main-domain
 * clock unit having PWM1 gated on, where GPIO0 could not be. The
 * trade is cheap here — PWM1 is already clocked at u-boot handoff
 * (the green light is lit before our kernel runs) and the same clock
 * unit is already reached at the top of kernel_main for the watchdog
 * silence — but if the lights ever go dark, led_pwm_init's
 * clock/reset/iomux writes in 003-pwm.c are the first suspect.
 *
 * The boot-stage code table the rest of the kernel uses is
 * documented in docs/015-led-diagnostic-codes.md — a developer
 * staring at the device with that table in hand can decode where
 * the kernel got stuck without any cable connected.
 */

#include <stdint.h>

/* The busy-wait delay utility lives in 002-main.c — kept as a
 * forward declaration so the slow-clock recalibration is the only
 * thing the hello flash changes. */
extern void delay_busy(uint64_t cycles);

/* PWM driver (003-pwm.c): the mechanism underneath this whole file.
 * led_pwm_init brings the PWM1 block up (clock, reset, pin routing)
 * and configures the three LED channels at zero duty; the rest drive
 * per-channel duty. Register-level detail lives in 003-pwm.c. */
extern void      led_pwm_init(void);
extern void      pwm_channel_set_duty(uintptr_t base, uint32_t duty);
extern uintptr_t pwm_channel_base(unsigned int channel);
extern uint32_t  pwm_full_duty(void);

/* Channel names — three names because the hardware has three
 * emitters: two in the top bicolor window (green + red) and one in
 * the bottom amber window. See this file's header comment for the
 * wiring. */
typedef enum {
    LED_GREEN = 0,   /* top window, green emitter */
    LED_AMBER = 1,   /* bottom window             */
    LED_RED   = 2,   /* top window, red emitter   */
    LED_COLOR_COUNT,
} led_color_t;

/* Each LED sits on one PWM1 channel (RK3568 PWM1 block, 003-pwm.c):
 * green on channel 5, amber on 6, red on 7. */
#define LED_CHANNEL_GREEN  5u
#define LED_CHANNEL_AMBER  6u
#define LED_CHANNEL_RED    7u

/* Resolve a colour name to its PWM channel number. Kept as a switch
 * (a dispatch table in disguise — three entries, all returning a
 * constant) so an out-of-range colour returns a sentinel 0, which
 * pwm_channel_base also rejects, rather than a wrong channel. */
static unsigned int led_channel(led_color_t color)
{
    switch (color) {
        case LED_GREEN: return LED_CHANNEL_GREEN;
        case LED_AMBER: return LED_CHANNEL_AMBER;
        case LED_RED:   return LED_CHANNEL_RED;
        default:        return 0u;
    }
}

/* Track the most recently applied boot stage so other layers (the
 * eMMC probe trigger in kernel_main, in particular) can read it back
 * without having to instrument the LED layer. */
static int last_stage = -1;

int led_current_stage(void)
{
    return last_stage;
}

/* Bring the LED subsystem up.
 *
 * Delegates to the PWM driver's bring-up (led_pwm_init): ungate the
 * PWM1 clock, release its resets, configure the three LED channels
 * for continuous output at zero duty — the lights start dark, and
 * the kernel paints stage signals over this blank state — and route
 * the three pins to their PWM function. After this call returns,
 * led_set is safe to call. */
void led_init(void)
{
    led_pwm_init();
}

/* Drive a light on or off.
 *
 * on  -> full duty (fully lit); off -> zero duty (dark). Brightness
 * gradations between the two are available through the PWM duty path
 * directly (the heartbeat uses them); the boot-stage vocabulary only
 * ever needs the two extremes, so its patterns stay legible on the
 * diffuser and match the diagnostic-codes table one-for-one. An
 * unknown colour resolves to channel 0, which pwm_channel_base
 * rejects, so the write is dropped rather than aimed at a wrong
 * address. */
void led_set(led_color_t color, int on)
{
    uintptr_t base = pwm_channel_base(led_channel(color));
    if (base == 0u) {
        return;
    }
    pwm_channel_set_duty(base, on ? pwm_full_duty() : 0u);
}

/* Boot stages — each one is a snapshot of the kernel's state
 * that has a corresponding LED pattern in
 * docs/015-led-diagnostic-codes.md. New stages are added at the
 * end as later issues land.
 *
 * The patterns these stages encode are expressed below in terms
 * of the three channel names (green / amber / red). The mapping
 * from channel names to physical lights: green and red are the two
 * emitters in the top bicolor window; amber is the bottom single-
 * color window. So "green on" lights the top green emitter alone;
 * "green on, red on" lights the top window's yellow-amber mix;
 * "amber on" lights the bottom; etc. */
typedef enum {
    /* Kernel reached the C entry — the simplest meaningful
     * post-boot signal. Pin pattern: green on, amber off,
     * red off. Visible: top window green, bottom window dark. */
    STAGE_KERNEL_MAIN     = 0,

    /* Issue 105's panic handler. Pin pattern: green off, amber
     * off, red on. Visible: top window red, bottom window dark. */
    STAGE_PANIC_GENERIC   = 1,

    /* Issue 109a's USB controller bring-up succeeded. Pin
     * pattern: green off, amber on, red off. Visible: top window
     * dark, bottom window amber. */
    STAGE_USB_CONTROLLER  = 2,

    /* Issue 110's CDC-ACM debug stream is live — host has
     * selected our configuration, bulk endpoints are armed,
     * debug_write can push text. Pin pattern: green on, amber
     * on, red on. Visible: top window yellow-amber, bottom
     * window amber. */
    STAGE_USB_ENUMERATED  = 3,

    /* Issue 110e's eMMC-to-microSD backup completed successfully.
     * Pin pattern: green off, amber on, red on. Visible: top
     * window red, bottom window amber. The developer powers off
     * and pulls the microSD card. */
    STAGE_BACKUP_COMPLETE = 4,

    STAGE_COUNT,
} boot_stage_t;

/* Calibration of the busy-wait cycle count for the hello flash.
 * The two halves of the flash (all-on, then all-off) each pause
 * for this many cycles.
 *
 * Tuning point: the SD-card boot test from issue 103e cycled the
 * GPIO probe at roughly two minutes per phase, which means the
 * CPU is running at something like the chip's crystal frequency
 * during early boot — none of the bootloader stages on the
 * SD-card path ramp up the CPU's phase-locked loops. Seven
 * million cycles lands at about a quarter-second at the observed
 * clock speed. When a future issue ramps the CPU clock to its
 * rated 1.8 GHz, this constant scales back up to give the same
 * visible duration. */
#define HELLO_FLASH_CYCLES   7000000ull

/* led_hello — the one-shot "I reached kernel_main" diagnostic.
 *
 * Lights all three channels (top window yellow-amber, bottom window
 * amber) together, holds, turns all off, holds again, returns.
 * Called from kernel_main right after led_init and before the
 * first stage signal. If the developer sees this flash, the
 * kernel reached its first C function. If the device powers on
 * with no LED activity at all, the boot chain failed somewhere
 * upstream and the kernel never ran.
 *
 * The all-channels-on pattern (top yellow-amber + bottom amber) is
 * distinct from every healthy stage signal in the boot-stage
 * table above — the closest is STAGE_USB_ENUMERATED, which is
 * the same pattern but reached after USB bring-up. The two are
 * distinguishable by duration (the hello is a momentary flash,
 * the stage signal is steady). See issue 106a for the broader
 * design discussion. */
void led_hello(void)
{
    led_set(LED_GREEN, 1);
    led_set(LED_AMBER, 1);
    led_set(LED_RED,   1);
    delay_busy(HELLO_FLASH_CYCLES);
    led_set(LED_GREEN, 0);
    led_set(LED_AMBER, 0);
    led_set(LED_RED,   0);
    delay_busy(HELLO_FLASH_CYCLES);
}

/* Breathing heartbeat state.
 *
 * A long-running operation calls led_heartbeat at a steady cadence
 * (currently the eMMC-to-SD backup in 016-emmc-backup.c, roughly one
 * call per megabyte copied). Each call steps the bottom amber
 * channel's duty up or down by a fraction of full, bouncing at the
 * extremes, so the amber light fades in and out — the smooth "still
 * working" signal from issue 106a, restored now that this layer
 * drives PWM rather than the on/off GPIO the 106b pivot used. If the
 * fade freezes mid-operation, the kernel is stuck.
 *
 * Amber (bottom window) rather than the top window because the top
 * window carries meaningful state in the stage-signal vocabulary
 * (green = kernel-main, red = panic-or-backup) that a pulsing
 * overlay would corrupt; the bottom amber light is idle outside the
 * USB-controller / USB-enumerated / backup-complete stages, so
 * pulsing it during a backup is unambiguous. */
static uint32_t heartbeat_level  = 0u;
static int      heartbeat_rising = 1;

/* led_heartbeat — advance the bottom amber light one breath step. */
void led_heartbeat(void)
{
    uint32_t full = pwm_full_duty();
    uint32_t step = full / 10u;          /* ~ten steps each way per breath */
    if (step == 0u) {
        step = 1u;
    }

    /* Rising: climb toward full, then flip to falling at the top.
     * Falling: drop toward zero, then flip to rising at the bottom.
     * The two clamps keep the level inside [0, full] no matter where
     * step lands relative to the current level. */
    if (heartbeat_rising) {
        if (heartbeat_level + step >= full) {
            heartbeat_level  = full;
            heartbeat_rising = 0;
        } else {
            heartbeat_level += step;
        }
    } else {
        if (heartbeat_level <= step) {
            heartbeat_level  = 0u;
            heartbeat_rising = 1;
        } else {
            heartbeat_level -= step;
        }
    }

    pwm_channel_set_duty(pwm_channel_base(LED_CHANNEL_AMBER), heartbeat_level);
}

/* Apply the LED pattern for a stage. The full table lives in
 * docs/015-led-diagnostic-codes.md; this switch keeps the source
 * in sync with that document. Updating either side must update
 * the other, or the documentation lies. */
void led_set_stage(boot_stage_t stage)
{
    last_stage = (int)stage;
    switch (stage) {
        case STAGE_KERNEL_MAIN:
            led_set(LED_GREEN, 1);
            led_set(LED_AMBER, 0);
            led_set(LED_RED,   0);
            break;

        case STAGE_PANIC_GENERIC:
            led_set(LED_GREEN, 0);
            led_set(LED_AMBER, 0);
            led_set(LED_RED,   1);
            break;

        case STAGE_USB_CONTROLLER:
            /* USB controller is alive but enumeration has not
             * happened yet. Bottom amber lit, top dark — the
             * visible pattern is unambiguously "the USB
             * controller bring-up step passed." */
            led_set(LED_GREEN, 0);
            led_set(LED_AMBER, 1);
            led_set(LED_RED,   0);
            break;

        case STAGE_USB_ENUMERATED:
            /* Host has enumerated us and CDC-ACM is live. All
             * three channels on — top window yellow-amber + bottom
             * amber. Same visible pattern as the hello flash
             * but held steady rather than flashed. */
            led_set(LED_GREEN, 1);
            led_set(LED_AMBER, 1);
            led_set(LED_RED,   1);
            break;

        case STAGE_BACKUP_COMPLETE:
            /* eMMC backed up to microSD; safe to power off and
             * pull the card. Top window red, bottom amber —
             * visually distinct from every other healthy stage
             * and from the panic pattern. */
            led_set(LED_GREEN, 0);
            led_set(LED_AMBER, 1);
            led_set(LED_RED,   1);
            break;

        default:
            /* Unknown stage — the caller has a bug. Light all
             * three channels so the developer notices something is
             * off; the steady-yellow-amber-plus-amber pattern
             * matches USB_ENUMERATED, so duration is the only
             * tell unless we add a unique pattern later. */
            led_set(LED_GREEN, 1);
            led_set(LED_AMBER, 1);
            led_set(LED_RED,   1);
            break;
    }
}
