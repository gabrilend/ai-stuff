/*
 * 020-chips.c — chip-scripts: the interactive-tool category (issue 116)
 *
 * The probe battery (019-probe-engine.c) is fire-and-log: a tiny declarative
 * script sweeps the hardware at boot and writes a machine-verifiable verdict
 * to the SD log, no human in the loop. A whole class of bring-up work is the
 * opposite shape — its only verdict is a person's ("yes, I felt the motor",
 * "yes, that key echoed"), or it needs a person to CHOOSE what runs next.
 * That is a menu, a prompt, a keypress; the probe DSL has no vocabulary for
 * it, deliberately. This file is where that work lives: chip-scripts, "chips"
 * for short — hand-written interactive C that drives a device (or a whole
 * subsystem) and asks the developer what happened.
 *
 * Probes are data; chips are code. They share only the drivers beneath both.
 *
 * The category holds two kinds of tool as they land:
 *   - the I/O device validation utility (issue 115) — the first chip here:
 *     drive rumble / display / audio / input and get a human's yes-or-no;
 *   - (later) a probe-selector — a menu of the compiled-in probes that arms
 *     the chosen ones and run_probes() them, instead of the boot sweep
 *     deciding for you.
 *
 * Everything a chip says goes out through debug_write (USB console + SD log);
 * everything it hears comes back through console_getchar — the read half of
 * the console added in 011-cdc-acm.c (issue 116). Without that read path a
 * menu could print but never listen, so this file has no reason to exist
 * before it.
 *
 * DORMANT BY DESIGN. run_chips() is the entry point, but nothing in
 * kernel_main calls it yet (issue 115: "we won't want it enabled just yet").
 * It is built, linked, and compile-verified so the machinery is ready; a
 * later trigger — a button chord, a USB console command — will call it. Like
 * the probe engine, the whole file is wrapped in SOREN_DEBUG, so a production
 * build (which globs every .c file under src/) compiles it to an empty object
 * and ships no chip code at all.
 */

#include <stdint.h>

#ifdef SOREN_DEBUG

/* The console, both directions (011-cdc-acm.c). debug_write narrates AT the
 * developer; console_getchar hears back one byte at a time (-1 = nothing yet),
 * console_readline gathers a whole typed line. */
extern void     debug_write(const char *text);
extern int      console_getchar(void);
extern uint32_t console_readline(char *buf, uint32_t max);

/* MMIO write for the rumble test's PWM channel. Reads are not needed here —
 * the verdict is a human's, not a register's. */
static inline void mmio_w32(uint32_t a, uint32_t v)
{
    *(volatile uint32_t *)(uintptr_t)a = v;
}

/* {{{ static void busy_delay() */
/* Spin a rough number of iterations — enough to hold a rumble pulse long
 * enough to feel. Not calibrated to wall-clock; "long enough for a human to
 * notice" is the whole requirement. */
static void busy_delay(uint32_t n)
{
    for (volatile uint32_t i = 0; i < n; i++) {
        /* nothing — the read/write of `i` is the delay */
    }
}
/* }}} */

/* {{{ static void put_char() */
/* Emit a single character through the console. debug_write wants a
 * NUL-terminated string, so wrap the byte in a two-char buffer. Used to echo
 * a pressed key so the developer sees what registered. */
static void put_char(char c)
{
    char s[2];
    s[0] = c;
    s[1] = 0;
    debug_write(s);
}
/* }}} */

/* {{{ static int ask_yes_no() */
/* Print a question, wait for a y or n keypress, echo it, and return 1 for
 * yes / 0 for no. Any other key is ignored and we keep waiting — the verdict
 * must be deliberate. This is the human half of every output-device test:
 * the device already did its thing, now the person says whether it worked. */
static int ask_yes_no(const char *question)
{
    debug_write(question);
    debug_write(" (y/n) ");
    for (;;) {
        int c = console_getchar();
        if (c < 0) {
            continue;                       /* no key yet — keep waiting */
        }
        if (c == 'y' || c == 'Y') { debug_write("y\r\n"); return 1; }
        if (c == 'n' || c == 'N') { debug_write("n\r\n"); return 0; }
        /* anything else: not a verdict, ignore and wait */
    }
}
/* }}} */

/* {{{ static int chip_menu() */
/* Render a titled, numbered list of options over the console, read a single
 * key selection, echo it, and return the chosen 0-based index — or -1 when
 * the developer presses q or ESC to go back. The reusable menu primitive at
 * the heart of the chips category: it is what proves I/O works end to end
 * (print, read, echo, branch), and every chip and sub-menu is built on it.
 * `n` is assumed <= 9 so each option maps to a single digit key. */
static int chip_menu(const char *title, const char *const *options, int n)
{
    debug_write("\r\n=== ");
    debug_write(title);
    debug_write(" ===\r\n");
    for (int i = 0; i < n; i++) {
        char num[4];
        num[0] = (char)('1' + i);
        num[1] = ')';
        num[2] = ' ';
        num[3] = 0;
        debug_write(num);
        debug_write(options[i]);
        debug_write("\r\n");
    }
    debug_write("q) back / quit\r\n> ");

    for (;;) {
        int c = console_getchar();
        if (c < 0) {
            continue;                       /* no key yet — keep waiting */
        }
        /* q or ESC: leave this menu. A back-out is a first-class choice, not
         * an error — a developer must always be able to escape a menu. */
        if (c == 'q' || c == 'Q' || c == 27) {
            debug_write("q\r\n");
            return -1;
        }
        /* A digit in range picks that option. */
        if (c >= '1' && c < '1' + n) {
            put_char((char)c);
            debug_write("\r\n");
            return c - '1';
        }
        /* Anything else: reprompt without redrawing the whole menu. */
        debug_write("\r\n[chips] not an option; pick 1-");
        put_char((char)('0' + n));
        debug_write(" or q\r\n> ");
    }
}
/* }}} */

/* ---- the I/O device validation chip (issue 115) ---------------------- */

/* {{{ static void io_test_console_echo() */
/* Validate the console INPUT device itself: the developer types, each key
 * echoes back, and they confirm every keypress registered. This is both a
 * real input-surface test and the honest proof that the read path (issue
 * 116) works — if the echo appears, console_getchar is delivering bytes. */
static void io_test_console_echo(void)
{
    debug_write("\r\n[chips] console echo self-test\r\n"
                "Type any characters; each should echo back.\r\n"
                "Press ESC when done.\r\n");
    for (;;) {
        int c = console_getchar();
        if (c < 0) {
            continue;                       /* nothing typed yet */
        }
        if (c == 27) {
            break;                          /* ESC ends the test */
        }
        if (c == '\r' || c == '\n') {
            debug_write("\r\n");
            continue;
        }
        put_char((char)c);                  /* echo the pressed key */
    }
    int ok = ask_yes_no("\r\nDid every key you pressed echo back?");
    debug_write(ok ? "[chips] VERDICT console-echo: PASS\r\n"
                   : "[chips] VERDICT console-echo: FAIL\r\n");
}
/* }}} */

/* The rumble channel: pwm@fe700020 (device-tree alias pwm14), a 16-byte PWM
 * channel window whose layout matches the LED channels in 003-pwm.c —
 * PERIOD at +0x04, DUTY at +0x08, CTRL at +0x0C. Duty is out of
 * PWM_PERIOD_TICKS: 0 = motor still, PERIOD = full. */
#define PWM3_CH_BASE       0xFE700020u
#define PWM_PERIOD_OFFSET  0x04u
#define PWM_DUTY_OFFSET    0x08u
#define PWM_CONTROL_OFFSET 0x0Cu
#define PWM_PERIOD_TICKS   1000u
/* enable | continuous | duty-positive — the same control word the LED
 * channels use (003-pwm.c: bit0 pwm_en, bit1 continuous, bit3 duty_pol). */
#define PWM_CTRL_ON        ((1u << 0) | (1u << 1) | (1u << 3))

/* {{{ static void rumble_pwm3_bringup() */
/* Bring the rumble PWM channel up enough to drive its duty, mirroring
 * pwm_channel_setup in 003-pwm.c: write PERIOD, start DUTY at 0 (still), then
 * CTRL. See issue 115 for the register facts.
 *
 * !!! NOT YET COMPLETE — the controller CLOCK-ungate, RESET-release, and
 * PIN-mux for this PWM block are not wired. The device tree gives them only
 * as phandles still to resolve: clocks = <clk 0x160, pclk 0x15f> (map to a
 * CLKGATE_CON register/bit the way 003-pwm.c's PWM1 uses CLKGATE_CON31), and
 * pinctrl-0 = <0xbd> (the rumble pad's IOMUX function). Until those land, if
 * the controller is not already clocked and the pad not already muxed to
 * this PWM, the duty writes reach a gated block and the motor stays still.
 * The gap is announced at runtime so a "no buzz" result is not mistaken for
 * a dead motor — a silent do-nothing would be the worse failure. */
static void rumble_pwm3_bringup(void)
{
    debug_write("[chips] rumble: PWM3 clock-ungate / reset-release / pin-mux "
                "are NOT wired yet (device-tree phandles unresolved). If no "
                "buzz is felt, that is the likely cause, not a dead motor.\r\n");
    mmio_w32(PWM3_CH_BASE + PWM_PERIOD_OFFSET, PWM_PERIOD_TICKS);
    mmio_w32(PWM3_CH_BASE + PWM_DUTY_OFFSET, 0u);       /* start still */
    mmio_w32(PWM3_CH_BASE + PWM_CONTROL_OFFSET, PWM_CTRL_ON);
}
/* }}} */

/* {{{ static void rumble_pwm3_drive() */
/* Set the rumble channel's duty. duty is clamped to PERIOD; 0 stops the
 * motor. The only knob the weak/strong pulses turn. */
static void rumble_pwm3_drive(uint32_t duty)
{
    if (duty > PWM_PERIOD_TICKS) {
        duty = PWM_PERIOD_TICKS;
    }
    mmio_w32(PWM3_CH_BASE + PWM_DUTY_OFFSET, duty);
}
/* }}} */

/* {{{ static void io_test_rumble() */
/* Pulse the vibration motor weak, then strong, asking after each whether it
 * was felt. Two pulses distinguish "motor works" from "motor works but the
 * weak boost is too low to notice" — a partial pass the verdict records. */
static void io_test_rumble(void)
{
    debug_write("\r\n[chips] rumble motor test (PWM3 @ 0xFE700020)\r\n");
    rumble_pwm3_bringup();

    debug_write("[chips] weak pulse...\r\n");
    rumble_pwm3_drive(PWM_PERIOD_TICKS / 10u);          /* ~10% duty */
    busy_delay(4000000u);
    rumble_pwm3_drive(0u);
    int weak = ask_yes_no("Did you feel a WEAK buzz?");

    debug_write("[chips] strong pulse...\r\n");
    rumble_pwm3_drive((PWM_PERIOD_TICKS * 9u) / 10u);   /* ~90% duty */
    busy_delay(4000000u);
    rumble_pwm3_drive(0u);
    int strong = ask_yes_no("Did you feel a STRONG buzz?");

    debug_write((weak && strong) ? "[chips] VERDICT rumble: PASS\r\n"
              : (weak || strong)  ? "[chips] VERDICT rumble: PARTIAL\r\n"
              :                     "[chips] VERDICT rumble: FAIL\r\n");
}
/* }}} */

/* {{{ static void chip_io_validation() */
/* The I/O device validation chip (issue 115): a sub-menu of per-device
 * tests. Grows an entry as each device's driver lands — display once the
 * framebuffer exists (111a-d), audio once the I2S path is up, buttons once
 * the phase-5 input drivers arrive. Reachable today: the console echo and
 * the rumble motor. */
static void chip_io_validation(void)
{
    static const char *const tests[] = {
        "Console echo self-test (proves the read path)",
        "Rumble motor (PWM3) — weak then strong",
    };
    for (;;) {
        int sel = chip_menu("I/O validation", tests, 2);
        if (sel < 0) {
            return;                         /* back to the top-level menu */
        }
        if (sel == 0) {
            io_test_console_echo();
        } else if (sel == 1) {
            io_test_rumble();
        }
    }
}
/* }}} */

/* ---- the chip registry and launcher ---------------------------------- */

/* The interactive analogue of builtin_probes[]. Unlike probes — generated
 * from input/probes/ into a baked fragment — chips are hand-written C, so the
 * table is a literal here: name, one-line description (the menu label), and
 * the function to run. New chips (the probe-selector, next) add a row. */
struct chip {
    const char *name;
    const char *description;
    void (*run)(void);
};

static const struct chip chips[] = {
    { "io-validation",
      "I/O device validation — confirm each device by hand, eye, or ear",
      chip_io_validation },
};
static const int chip_count = (int)(sizeof(chips) / sizeof(chips[0]));

/* {{{ void run_chips() */
/* The chips launcher — a top-level menu of the registered chips; pick one,
 * it runs, and you return here when it backs out. This is the entry point a
 * button chord or a USB console command will one day call.
 *
 * DORMANT: kernel_main does not call this. It exists, built and linked, so
 * the machinery is proven and ready; wiring a trigger to it is a later,
 * deliberate step (issue 115). It needs the USB console open on the host —
 * the menu prints to /dev/ttyACM0 and reads the selection back from it. */
void run_chips(void)
{
    debug_write("\r\n[chips] interactive chip-scripts — type into the USB "
                "console (/dev/ttyACM0) to drive the menu\r\n");

    const char *labels[8];
    for (;;) {
        int n = (chip_count < 8) ? chip_count : 8;
        for (int i = 0; i < n; i++) {
            labels[i] = chips[i].description;
        }
        int sel = chip_menu("chip-scripts", labels, n);
        if (sel < 0) {
            break;                          /* developer chose to leave */
        }
        debug_write("[chips] launching: ");
        debug_write(chips[sel].name);
        debug_write("\r\n");
        chips[sel].run();
    }
    debug_write("[chips] done\r\n");
}
/* }}} */

#endif /* SOREN_DEBUG */
