/*
 * 005-vectors.s — aarch64 exception vector table
 *
 * The aarch64 architecture requires a 2 KB-aligned table of sixteen
 * 128-byte vectors pointed to by VBAR_EL1. The CPU jumps to a
 * specific entry based on exception type (synchronous, IRQ, FIQ,
 * SError) and exception source (current EL with SP0, current EL with
 * SPx, lower EL using AArch64, lower EL using AArch32). Sixteen
 * combinations, sixteen entries, table size 0x800 bytes.
 *
 * Phase 1's policy: catch every exception type as a generic panic.
 * The point per issue 105 is that a misbehaving piece of code
 * produces a *legible failure* — a red LED, eventually a text
 * trace through the USB debug channel issue 110 brings up — rather
 * than a silent hang. Phase 2 will replace this with real interrupt
 * dispatching when the threading core needs it.
 *
 * Each entry puts the vector index into x0 and branches to
 * common_panic. The common stub captures the faulting PC (ELR_EL1)
 * and exception syndrome (ESR_EL1) and calls into the C
 * panic_handler in 006-panic.c. panic_handler is not expected to
 * return; if it does, the stub sits in WFI.
 *
 * The vector index encoding:
 *
 *   0..3   current EL with SP0  — unused in this kernel (we use SPx)
 *   4..7   current EL with SPx  — what synchronous bugs go through
 *   8..11  lower EL using AArch64 — unused (we never drop to a lower EL)
 *   12..15 lower EL using AArch32 — also unused
 *
 * Within each block of four:
 *   +0 synchronous, +1 IRQ, +2 FIQ, +3 SError
 *
 * So a bad pointer in kernel code shows up as vector index 4 (sync
 * from current EL with SPx).
 */

.section .text.vectors, "ax"
.balign 2048

.global vector_table
vector_table:

/* Each entry puts a numeric index in x0 and branches to the common
 * panic stub. The macro pads to the architecture-mandated 128-byte
 * vector size so the next entry lands at the right offset. */
.macro VECTOR_ENTRY index
    mov     x0, #\index
    b       common_panic
    .balign 128
.endm

/* Current EL with SP0 — we use SPx exclusively, so these never fire. */
    VECTOR_ENTRY 0
    VECTOR_ENTRY 1
    VECTOR_ENTRY 2
    VECTOR_ENTRY 3

/* Current EL with SPx — where our kernel-mode bugs land. */
    VECTOR_ENTRY 4
    VECTOR_ENTRY 5
    VECTOR_ENTRY 6
    VECTOR_ENTRY 7

/* Lower EL using AArch64 — we never drop, but slots are mandatory. */
    VECTOR_ENTRY 8
    VECTOR_ENTRY 9
    VECTOR_ENTRY 10
    VECTOR_ENTRY 11

/* Lower EL using AArch32 — also mandatory placeholder slots. */
    VECTOR_ENTRY 12
    VECTOR_ENTRY 13
    VECTOR_ENTRY 14
    VECTOR_ENTRY 15

/* common_panic
 *
 * Reached from every vector. Receives the vector index in x0.
 * Captures ELR_EL1 (faulting PC) and ESR_EL1 (exception syndrome)
 * into x1 and x2, then calls into the C panic_handler with
 * (vector_index, faulting_pc, syndrome).
 *
 * panic_handler is declared __attribute__((noreturn)) on the C side,
 * but we sit in a low-power wait loop here too in case it does ever
 * return — defensive against future bugs.
 */
common_panic:
    mrs     x1, elr_el1
    mrs     x2, esr_el1
    bl      panic_handler

1:
    wfi
    b       1b
