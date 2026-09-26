/*
 * 044-identity-map.c — the memory map that turns the caches on (issue 201).
 *
 * UNVERIFIED ON HARDWARE.
 *
 * General description: with no translation table loaded, the chip treats
 * every access as "device" memory — nothing cached, unaligned accesses
 * fault, and the exclusive-access instructions every lock-free step of the
 * engine is built from are undefined. This file builds one table that maps
 * every address to itself and exists only for its second column: RAM is
 * marked normal, cached, and inner-shareable (so all four cores keep one
 * coherent view and the exclusive monitor arbitrates between them); the
 * peripheral windows are marked device memory (every write reaches its
 * register, in order, exactly once). No address changes meaning.
 *
 * The table uses one-gigabyte blocks, the coarsest the architecture
 * allows, because the whole map is four rows (docs/016-physical-memory-
 * map.md): three gigabytes of RAM from address zero, then the gigabyte
 * that holds every peripheral window. Phase 9 replaces this with a finer
 * table whose rows carry per-app access rights.
 *
 * This assumes the kernel runs at exception level 1 (the registers it
 * writes are the _EL1 ones), which 001-boot.s already assumes by writing
 * vbar_el1. Issue 202's first open question is whether that is true on
 * this bootloader; if it is not, these writes silently configure the
 * wrong level and the table does nothing.
 */
#include <stdint.h>

#define ATTR_NORMAL 0                  /* index into MAIR: normal, write-back, read/write-allocate */
#define ATTR_DEVICE 1                  /* index into MAIR: device, non-gathering, non-reordering, no early ack */

#define DESC_BLOCK      0x1ull
#define DESC_AF         (1ull << 10)   /* accessed flag: set, or the first touch faults */
#define DESC_SH_INNER   (3ull << 8)
#define DESC_ATTR(i)    ((uint64_t)(i) << 2)
#define DESC_PXN        (1ull << 53)
#define DESC_UXN        (1ull << 54)
#define GB              (1ull << 30)

/* One level-1 table: 512 rows, each a gigabyte. Aligned to its size, as
 * the table-base register requires. It lives in the kernel image's own
 * data, which the table itself maps as normal RAM (issue 201's open
 * question "where does the table itself live", answered). */
static uint64_t level1[512] __attribute__((aligned(4096)));
static int      built;

/* {{{ build_identity_map */
static void build_identity_map(void)
{
    for (int i = 0; i < 512; i++) {
        level1[i] = 0;                 /* invalid: an access here faults, loudly */
    }
    /* 0–3 GB: RAM. */
    for (uint64_t g = 0; g < 3; g++) {
        level1[g] = (g * GB) | DESC_BLOCK | DESC_AF | DESC_SH_INNER | DESC_ATTR(ATTR_NORMAL);
    }
    /* 3–4 GB: every peripheral window. Never executable. */
    level1[3] = (3 * GB) | DESC_BLOCK | DESC_AF | DESC_ATTR(ATTR_DEVICE) | DESC_PXN | DESC_UXN;
    built = 1;
}
/* }}} */

/* {{{ mmu_enable_on_this_core */
/* The table is shared; the register that points at it and the bit that
 * switches it on are per core, so every core calls this for itself. */
void mmu_enable_on_this_core(void)
{
    if (!built) {
        build_identity_map();
    }
    uint64_t mair = (0xFFull << (8 * ATTR_NORMAL)) | (0x00ull << (8 * ATTR_DEVICE));
    uint64_t tcr  = (25ull << 0)       /* T0SZ: 39-bit addresses */
                  | (1ull << 8)        /* IRGN0: write-back, write-allocate */
                  | (1ull << 10)       /* ORGN0: write-back, write-allocate */
                  | (3ull << 12)       /* SH0: inner shareable */
                  | (0ull << 14)       /* TG0: 4 KB granule */
                  | (1ull << 23)       /* EPD1: no upper-half table */
                  | (1ull << 32);      /* IPS: 36-bit physical addresses */
    __asm__ volatile(
        "msr mair_el1, %0\n"
        "msr tcr_el1, %1\n"
        "msr ttbr0_el1, %2\n"
        "isb\n"
        "tlbi vmalle1\n"
        "ic iallu\n"
        "dsb ish\n"
        "isb\n"
        :: "r"(mair), "r"(tcr), "r"((uint64_t)(uintptr_t)level1) : "memory");
    uint64_t sctlr;
    __asm__ volatile("mrs %0, sctlr_el1" : "=r"(sctlr));
    sctlr |= (1ull << 0)               /* M: translation (and attributes) on */
           | (1ull << 2)               /* C: data cache on */
           | (1ull << 12);             /* I: instruction cache on */
    sctlr &= ~(1ull << 1);             /* A: unaligned accesses allowed on normal memory */
    __asm__ volatile("msr sctlr_el1, %0\n isb" :: "r"(sctlr) : "memory");
}
/* }}} */
