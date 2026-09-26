/*
 * 043-cores.s — where a freshly released core starts, and the snapshot a
 * faulting box returns to (issues 202 and 214).
 *
 * UNVERIFIED ON HARDWARE.
 *
 * General description: a core the secure firmware has just switched on
 * arrives at secondary_entry with nothing — no stack, no exception table,
 * caches off, no idea which core it is. The firmware hands over one
 * number, which the boot core chose to be the core's own number. This
 * stub gives the core its stack (from a table the boot core filled), the
 * same exception table core 0 uses, its number in the per-core register
 * the engine reads, and the caches (by switching on its own view of the
 * shared memory table from 201), then calls into C.
 *
 * The snapshot pair is a hand-written setjmp/longjmp: taking a snapshot
 * saves the registers a C function must preserve plus the stack pointer
 * and return address; returning to one restores them and makes the
 * original "take" appear to return a second time, with 1.
 */

.section .text, "ax"

.global secondary_entry
secondary_entry:
    msr     DAIFSet, #0xF              /* nothing may interrupt a core that has no handlers set up */
    /* x0 = this core's number, as passed to the firmware's CPU_ON. */
    mov     x19, x0
    ldr     x1, =core_stack_top
    ldr     x2, [x1, x19, lsl #3]
    mov     sp, x2
    ldr     x1, =vector_table
    msr     vbar_el1, x1
    msr     tpidr_el1, x19
    isb
    bl      mmu_enable_on_this_core
    mov     x0, x19
    bl      device_secondary_main
1:
    wfe
    b       1b

/* int guard_snapshot_take(uint64_t *buffer) */
.global guard_snapshot_take
guard_snapshot_take:
    stp     x19, x20, [x0, #0]
    stp     x21, x22, [x0, #16]
    stp     x23, x24, [x0, #32]
    stp     x25, x26, [x0, #48]
    stp     x27, x28, [x0, #64]
    stp     x29, x30, [x0, #80]
    mov     x1, sp
    str     x1, [x0, #96]
    mov     x0, #0
    ret

/* void guard_snapshot_return(uint64_t *buffer) — never returns to its caller */
.global guard_snapshot_return
guard_snapshot_return:
    ldp     x19, x20, [x0, #0]
    ldp     x21, x22, [x0, #16]
    ldp     x23, x24, [x0, #32]
    ldp     x25, x26, [x0, #48]
    ldp     x27, x28, [x0, #64]
    ldp     x29, x30, [x0, #80]
    ldr     x1, [x0, #96]
    mov     sp, x1
    mov     x0, #1
    ret
