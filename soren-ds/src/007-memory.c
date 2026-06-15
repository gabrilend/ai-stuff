/*
 * 007-memory.c — physical memory layout
 *
 * Defines the DRAM region the page allocator (issue 108) hands out
 * from. The chip's full physical address space — including every
 * peripheral register window — is catalogued in
 * docs/016-physical-memory-map.md; this file only exports the
 * subset the kernel's memory allocator actually consumes at
 * runtime.
 *
 * The memory model is step one from docs/007-memory-model.md: flat
 * physical addressing, MMU disabled, one address space shared by
 * everything. Phase 9 turns on the MMU for protection; this file's
 * values move from "physical address" to "physical address that is
 * also the virtual address" semantically, without changing the
 * numbers.
 */

#include <stdint.h>

/* DRAM extents. The Anbernic RG DS has 3 GB of LPDDR4 starting at
 * physical address zero. The full DRAM map and the reservation
 * convention live in docs/016-physical-memory-map.md. */
#define DRAM_BASE  ((uint64_t)0x0000000000000000ull)
#define DRAM_END   ((uint64_t)0x00000000C0000000ull)

/* Lower-layer firmware (BL31 / Anbernic u-boot) occupies the
 * bottom slice of DRAM. We never touch this range. The boundary
 * is the standard Rockchip Android boot.img kernel load address,
 * which is also the address kernel.ld pins as the kernel's
 * starting offset. */
#define PRE_KERNEL_END ((uint64_t)0x0000000000280000ull)

/* The linker script defines __stack_top at the highest address the
 * kernel image itself uses (top of the reserved kernel stack). Any
 * DRAM above that is fair game for the allocator. */
extern char __stack_top[];

/* Round an address up to the next page boundary. The kernel
 * allocator works in 4 KB pages. */
#define PAGE_SIZE      ((uint64_t)4096)
#define PAGE_ALIGN_UP(x)  (((x) + (PAGE_SIZE - 1)) & ~(PAGE_SIZE - 1))

/* The start of free DRAM, just above the kernel image's reserved
 * stack region. Page-aligned so the allocator does not have to
 * mask the value itself. */
uint64_t memory_pool_base(void)
{
    return PAGE_ALIGN_UP((uint64_t)(uintptr_t)__stack_top);
}

/* The end of free DRAM. Aligned down to the page just to match the
 * allocator's expectations of a half-open range. */
uint64_t memory_pool_end(void)
{
    return DRAM_END & ~(PAGE_SIZE - 1);
}

/* The size of the free pool, in bytes. Convenience over having
 * every caller compute it themselves. */
uint64_t memory_pool_size(void)
{
    return memory_pool_end() - memory_pool_base();
}
