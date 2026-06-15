/*
 * 006-panic.c — kernel panic handler
 *
 * Called from common_panic in 005-vectors.s when any exception
 * vector fires. Receives three pieces of state captured at the
 * point of failure:
 *
 *   vector       — which entry of the 16-slot table was taken,
 *                  indicating the exception type and source. See
 *                  the comment block in 005-vectors.s for the
 *                  encoding.
 *   faulting_pc  — the program counter at the moment of the
 *                  exception, captured from ELR_EL1. For a sync
 *                  fault this is the instruction that faulted; for
 *                  asynchronous exceptions it is the instruction
 *                  the core was about to execute when the
 *                  exception was delivered.
 *   syndrome     — the contents of ESR_EL1, encoding the exception
 *                  class and a class-specific instruction
 *                  syndrome. Decoded by the ARM architecture
 *                  reference manual section D17.2.43.
 *
 * Phase 1's panic policy is minimal: light the red LED via the
 * boot-stage pattern STAGE_PANIC_GENERIC, then sit in WFI forever.
 * There is no way to report the captured state in detail yet —
 * issue 110 (USB CDC-ACM debug stream) will add a text channel that
 * future panic versions will write the vector / PC / syndrome
 * through. For now, "red LED solid" is the only output, and the
 * developer reflashes a known-good kernel after a power-cycle.
 *
 * The function is marked noreturn so the C compiler can both omit
 * the call-site return-address bookkeeping and emit a warning if
 * we ever accidentally fall through.
 */

#include <stdint.h>

extern void led_set_stage(int stage);

/* Must match boot_stage_t in 004-led.c. Defining it again here
 * rather than threading a shared header keeps the phase 1 source
 * tree flat and explicit. When the LED stage table changes, this
 * line and 002-main.c's same #define must both change too. */
#define STAGE_PANIC_GENERIC 1

__attribute__((noreturn))
void panic_handler(uint64_t vector, uint64_t faulting_pc, uint64_t syndrome)
{
    /* Suppress unused-parameter warnings while the captured state
     * has nowhere to go. Future versions of this function read
     * these out and emit them through the USB debug stream. */
    (void)vector;
    (void)faulting_pc;
    (void)syndrome;

    /* The first observable signal of the panic: solid red, with
     * green and amber off. See docs/015-led-diagnostic-codes.md
     * for the pattern table. */
    led_set_stage(STAGE_PANIC_GENERIC);

    /* Park the core. WFI returns on any interrupt, even masked
     * ones in some implementations; the surrounding loop catches
     * that case and re-enters WFI. */
    while (1) {
        __asm__ volatile ("wfi");
    }
}
