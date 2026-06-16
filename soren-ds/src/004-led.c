/*
 * 004-led.c — LED abstraction and boot-stage signaling, via GPIO
 *
 * Two physical lights on the front edge of the Anbernic RG DS:
 *
 *   top window     A bicolor LED with separate green and red
 *                  emitters behind one diffuser. Driving the
 *                  green-named pin lights the green emitter;
 *                  driving the red-named pin lights the red
 *                  emitter; driving both at once additively mixes
 *                  to a yellow-amber appearance brighter than
 *                  either alone.
 *
 *   bottom window  A single-color amber LED, driven by the
 *                  amber-named pin.
 *
 * The names green / amber / red — kept here for source
 * compatibility with the PWM-era LED layer and for matching the
 * device tree's labels — describe the *pins* the layer's
 * primitives accept, not the *physical lights* a user sees. The
 * mapping from pin names to visible patterns is documented in
 * docs/015-led-diagnostic-codes.md alongside the boot-stage
 * table that drives this file.
 *
 * The three pins are routed through the chip's GPIO controller
 * rather than its PWM controller. Issue 106b describes the why;
 * the short version is that the PWM controller's clock and
 * pin-multiplexer routing are not configured by the bootloader
 * on the SD-card boot path, so any LED layer that depends on
 * PWM produces silence on hardware. The GPIO controller in the
 * always-on PMU clock subtree needs neither — the LED layer's
 * setup writes can drive it directly the moment `kernel_main`
 * runs. Issue 106c brings PWM back, restoring the smoother
 * brightness vocabulary; this file lives in the GPIO world
 * until then.
 *
 * The boot-stage code table the rest of the kernel uses is
 * documented in docs/015-led-diagnostic-codes.md — a developer
 * staring at the device with that table in hand can decode where
 * the kernel got stuck without any cable connected.
 */

#include <stdint.h>

/* The busy-wait delay utility lives in 002-main.c — same
 * forward-declaration discipline the PWM-era code used, kept so
 * the slow-clock recalibration is the only thing the hello flash
 * changes. */
extern void delay_busy(uint64_t cycles);

/* Pin names — three names because the device tree labels three
 * pins, kept across the PWM-to-GPIO transition for source
 * compatibility with the boot-stage table further down. The
 * physical lights these pin names correspond to is one bicolor
 * top window (green pin + red pin) and one bottom amber window
 * (amber pin); see this file's header comment for the wiring. */
typedef enum {
    LED_GREEN = 0,   /* top window, green emitter */
    LED_AMBER = 1,   /* bottom window */
    LED_RED   = 2,   /* top window, red emitter */
    LED_COLOR_COUNT,
} led_color_t;

/* Peripheral register addresses. Kept here as plain literals
 * rather than #include'd from a chip header because phase 1 has
 * no shared register catalogue yet — every driver harvests its
 * addresses from docs/016-physical-memory-map.md. The three
 * windows used here all live in the chip's always-on PMU
 * subtree, so neither needs a clock-gate write to be operational
 * before we use it. */
#define PMU_GRF_BASE              0xFDC20000u
#define PMU_GRF_GPIO0C_IOMUX_H    (PMU_GRF_BASE + 0x14)
#define GPIO0_BASE                0xFDD60000u
#define GPIO0_SWPORT_DR_H         (GPIO0_BASE + 0x04)
#define GPIO0_SWPORT_DDR_H        (GPIO0_BASE + 0x0C)

/* Bit positions within the data and direction high-half
 * registers for the three LED pins. GPIO0 numbers its pins
 * flat 0..31 (A0..D7 in the chip's naming); the high-half
 * registers carry pins 16..31, with the named pin's bit in
 * each register at (pin_number - 16). The three LED pins are
 * C4 = 20, C5 = 21, C6 = 22; in the high-half registers that
 * is bits 4, 5, 6. */
#define LED_PIN_BIT_GREEN   (1u << 4)   /* C4, top green emitter */
#define LED_PIN_BIT_AMBER   (1u << 5)   /* C5, bottom amber LED  */
#define LED_PIN_BIT_RED     (1u << 6)   /* C6, top red emitter   */
#define LED_PIN_BIT_ALL     (LED_PIN_BIT_GREEN | LED_PIN_BIT_AMBER | LED_PIN_BIT_RED)

/* Volatile-pointer MMIO accessor. The volatile qualifier stops
 * the compiler from collapsing repeated writes to the same
 * address; with the MMU off (phase 1 policy until issue 901
 * turns it on) all peripheral accesses are Device-nGnRnE by
 * architecture default, so the writes are also strongly
 * ordered against each other without extra barriers. */
static inline void mmio_write32(uintptr_t address, uint32_t value)
{
    *(volatile uint32_t *)address = value;
}

/* Resolve a color name to its bit in the GPIO data and direction
 * registers. The switch is a dispatch table in disguise (three
 * entries, all returning a constant) — kept as a switch so an
 * out-of-range color produces a sentinel rather than a wrong
 * pin. */
static uint32_t led_pin_bit(led_color_t color)
{
    switch (color) {
        case LED_GREEN: return LED_PIN_BIT_GREEN;
        case LED_AMBER: return LED_PIN_BIT_AMBER;
        case LED_RED:   return LED_PIN_BIT_RED;
        default:        return 0;
    }
}

/* Track the most recently applied boot stage so other layers
 * (the eMMC probe trigger in kernel_main, in particular) can
 * read it back without having to instrument the LED layer. */
static int last_stage = -1;

int led_current_stage(void)
{
    return last_stage;
}

/* Bring the LED subsystem up.
 *
 * Three writes, all using the chip-family's write-mask
 * convention (upper sixteen bits select which lower-sixteen bits
 * the hardware updates; bits the mask does not name stay
 * unchanged):
 *
 *   1. Pin-multiplexer override. Clear the function fields for
 *      C4 / C5 / C6 in the PMU GRF's high-half IOMUX register
 *      so the three pins are owned by the GPIO controller
 *      rather than the PWM controller (or whatever the
 *      bootloader may have left them on). Function 0 = GPIO.
 *
 *   2. Direction. Mark pins 20 / 21 / 22 (= C4 / C5 / C6) as
 *      outputs in the GPIO0 high-half direction register.
 *
 *   3. Initial value. Drive all three pins low so the lights
 *      start dark — the kernel paints stage signals over this
 *      blank state.
 *
 * After this call returns, led_set is safe to call. */
void led_init(void)
{
    /* Pinmux: function 0 (GPIO) for C4 / C5 / C6.
     * Mask covers bits 0-11 in the low half (one four-bit
     * function field per pin); value half is zero, so each
     * field goes to function 0. The fourth pin in the same
     * register (C7) stays at whatever function it was on. */
    mmio_write32(PMU_GRF_GPIO0C_IOMUX_H, 0x0FFF0000u);

    /* Direction: outputs for the three LED pin bits.
     * Mask half names which bits in the low half this write
     * changes; value half has the bits set, so the pins
     * become outputs. */
    mmio_write32(GPIO0_SWPORT_DDR_H,
                 ((uint32_t)LED_PIN_BIT_ALL << 16) | LED_PIN_BIT_ALL);

    /* Initial value: all three pins low.
     * Mask half names the three bits; value half is zero, so
     * the lights start dark. */
    mmio_write32(GPIO0_SWPORT_DR_H,
                 ((uint32_t)LED_PIN_BIT_ALL << 16));
}

/* Drive a pin on or off.
 *
 * Single write to the GPIO0 data register's high half, using
 * the write-mask convention so the other two LED pins (and the
 * fourth pin sharing the register) stay where they are. The
 * caller passes a logical color name; this function maps it to
 * the appropriate bit and assembles the data word. */
void led_set(led_color_t color, int on)
{
    uint32_t bit = led_pin_bit(color);
    if (bit == 0) {
        return;
    }
    /* Mask half: just this pin's bit. Value half: the pin's bit
     * if `on`, zero if off. */
    uint32_t mask_half  = bit << 16;
    uint32_t value_half = on ? bit : 0;
    mmio_write32(GPIO0_SWPORT_DR_H, mask_half | value_half);
}

/* Boot stages — each one is a snapshot of the kernel's state
 * that has a corresponding LED pattern in
 * docs/015-led-diagnostic-codes.md. New stages are added at the
 * end as later issues land.
 *
 * The patterns these stages encode are expressed below in terms
 * of the three pin names (green / amber / red) the original PWM-
 * era code used. The mapping from pin names to physical lights:
 * green and red are the two emitters in the top bicolor window;
 * amber is the bottom single-color window. So "green on" lights
 * the top green emitter alone; "green on, red on" lights the top
 * window's yellow-amber mix; "amber on" lights the bottom; etc. */
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
 * Lights all three pins (top window yellow-amber, bottom window
 * amber) together, holds, turns all off, holds again, returns.
 * Called from kernel_main right after led_init and before the
 * first stage signal. If the developer sees this flash, the
 * kernel reached its first C function. If the device powers on
 * with no LED activity at all, the boot chain failed somewhere
 * upstream and the kernel never ran.
 *
 * The all-pins-on pattern (top yellow-amber + bottom amber) is
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

/* Discrete heartbeat state.
 *
 * The PWM-era heartbeat in issue 106a stepped a brightness
 * counter and applied each step as a duty value, producing a
 * smooth fade-in / fade-out. The GPIO-era heartbeat in this file
 * has no brightness vocabulary — every write is on or off — so
 * the breathing becomes a blink. One static bit, flipped on each
 * call, drives the bottom amber LED.
 *
 * The signal content (the long backup is still making forward
 * progress) is preserved; the aesthetic loses the smooth
 * breathing. Issue 106c restores the breathing once the PWM
 * controller is brought up cleanly. */
static int heartbeat_on = 0;

/* led_heartbeat — toggle the bottom amber LED.
 *
 * Called from long-running operations (currently the
 * eMMC-to-SD backup in 016-emmc-backup.c) at a steady cadence,
 * roughly one call per megabyte copied. The bottom amber LED
 * blinks on and off; if the blinking stops mid-operation, the
 * operation is stuck.
 *
 * Amber rather than the top window's pin choices because the
 * top window carries meaningful state in the stage signal
 * vocabulary (green = kernel-main, red = panic-or-backup) and
 * we do not want to override its semantics. The bottom amber
 * LED is unused outside USB-controller / USB-enumerated /
 * backup-complete stages, so toggling it during the backup
 * makes the blink unambiguous. */
void led_heartbeat(void)
{
    heartbeat_on = !heartbeat_on;
    led_set(LED_AMBER, heartbeat_on);
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
             * three pins on — top window yellow-amber + bottom
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
             * three pins so the developer notices something is
             * off; the steady-yellow-amber-plus-amber pattern
             * matches USB_ENUMERATED, so duration is the only
             * tell unless we add a unique pattern later. */
            led_set(LED_GREEN, 1);
            led_set(LED_AMBER, 1);
            led_set(LED_RED,   1);
            break;
    }
}
