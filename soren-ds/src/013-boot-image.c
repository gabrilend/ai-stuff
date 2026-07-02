/*
 * 013-boot-image.c — write the kernel to the eMMC boot partition
 *
 * Builds an Android boot.img header pointing at our kernel, writes
 * the header followed by the kernel bytes to the eMMC's boot
 * partition, then reads the header back to verify the write
 * landed intact. After this runs successfully, the device boots
 * SoreOS from eMMC with no SD card present — the install pipeline
 * the project committed to in 014-hardware-overview.md is then
 * complete from the boot side.
 *
 * The Android boot.img format the Anbernic u-boot expects starts
 * with a 64-byte header (eight magic bytes, then ten 32-bit
 * fields), continues through a 16-byte name and a 512-byte
 * command-line, an 8-element SHA-1 ID array, and a 1024-byte
 * extra command-line, all of which together fit in one 4096-byte
 * "page" the format defines. The kernel bytes start in the next
 * page; the ramdisk (which we do not have) would start after
 * that, also page-aligned.
 *
 * Phase 1's choices:
 *   - header_version: 0 (the simplest variant of boot.img)
 *   - page_size: 4096
 *   - kernel load address: 0x02000000 (matches kernel.ld; the
 *     same address ROCKNIX's u-boot uses on the SD-card path,
 *     so the kernel runs from the same physical address on
 *     both boot paths and the linker's literal-pool addresses
 *     stay valid regardless of which u-boot launched us)
 *   - no ramdisk, no second-stage bootloader, no DTB
 *   - SHA-1 ID is left as zeros — Anbernic's u-boot does not
 *     verify image integrity at this layer
 *
 * The boot partition's location on eMMC is a fixed LBA for phase 1
 * rather than parsed from the GPT (which would add signature
 * checks, partition-entry walking, UTF-16 name matching). The value
 * was validated on hardware by the 110e layout probe — it is LBA
 * 51200, the `boot` partition per the device GPT. A fixed LBA is
 * still a per-device assumption; the general version parses the GPT
 * to find `boot` by name.
 */

#include <stdint.h>

extern int  emmc_init(void);
extern int  emmc_read_block(uint32_t lba, uint8_t *buffer);
extern int  emmc_write_block(uint32_t lba, const uint8_t *buffer);
extern void debug_write(const char *text);
extern uint64_t alloc_page(void);

/* Linker-exposed boundary marking the end of the on-disk kernel
 * image — see kernel.ld. The bytes between the kernel's load
 * address and this symbol are the bytes that need to land on
 * eMMC. */
extern char __image_end[];

/* The kernel's load address — must match kernel.ld and the
 * boot.img header's kernel_addr field. */
#define KERNEL_LOAD_ADDR 0x02000000u

/* Boot-partition LBA, confirmed from the device's own GPT by the
 * 110e layout probe (see docs/024-emmc-partition-map.md): the
 * `boot` partition (partition 7, 64 MiB) starts at LBA 51200. The
 * earlier placeholder 0x4000 (16384) was WRONG — that LBA is the
 * `uboot` partition, and writing a kernel there would corrupt the
 * bootloader and brick the device. This value is device-confirmed,
 * not datasheet-general; the assumption-free version parses the GPT
 * to locate `boot` by name rather than trusting a fixed LBA. */
#define BOOT_PARTITION_LBA 51200u

/* Android boot.img header — version 0. The struct layout is
 * exactly what the format specifies; any reordering breaks the
 * bootloader's parse. */
struct __attribute__((packed)) android_boot_img_hdr {
    uint8_t  magic[8];           /* "ANDROID!" */
    uint32_t kernel_size;
    uint32_t kernel_addr;
    uint32_t ramdisk_size;
    uint32_t ramdisk_addr;
    uint32_t second_size;
    uint32_t second_addr;
    uint32_t tags_addr;
    uint32_t page_size;
    uint32_t header_version;
    uint32_t os_version;
    uint8_t  name[16];
    uint8_t  cmdline[512];
    uint32_t id[8];
    uint8_t  extra_cmdline[1024];
};

/* The boot.img header occupies one 4096-byte page on the disk
 * regardless of its actual struct size. We pad to a full page. */
#define BOOT_IMG_PAGE_SIZE 4096u
#define EMMC_BLOCK_SIZE    512u
#define PAGE_BLOCKS        (BOOT_IMG_PAGE_SIZE / EMMC_BLOCK_SIZE)

/* Build the boot.img header in the caller's buffer. The buffer
 * must be at least BOOT_IMG_PAGE_SIZE bytes; the header is
 * written at the start and the rest is zero-padded. */
static void build_boot_image_header(uint8_t *page_buffer,
                                    uint32_t kernel_size_bytes)
{
    /* Zero the whole page so any unwritten field reads as 0. */
    for (uint32_t i = 0; i < BOOT_IMG_PAGE_SIZE; i++) {
        page_buffer[i] = 0;
    }

    struct android_boot_img_hdr *h =
        (struct android_boot_img_hdr *)page_buffer;

    h->magic[0] = 'A'; h->magic[1] = 'N'; h->magic[2] = 'D';
    h->magic[3] = 'R'; h->magic[4] = 'O'; h->magic[5] = 'I';
    h->magic[6] = 'D'; h->magic[7] = '!';
    h->kernel_size    = kernel_size_bytes;
    h->kernel_addr    = KERNEL_LOAD_ADDR;
    h->ramdisk_size   = 0;
    h->ramdisk_addr   = 0;
    h->second_size    = 0;
    h->second_addr    = 0;
    h->tags_addr      = 0;
    h->page_size      = BOOT_IMG_PAGE_SIZE;
    h->header_version = 0;
    h->os_version     = 0;
    h->name[0]  = 'S'; h->name[1]  = 'o'; h->name[2]  = 'r';
    h->name[3]  = 'e'; h->name[4]  = 'n'; h->name[5]  = ' ';
    h->name[6]  = 'D'; h->name[7]  = 'S'; h->name[8]  = 0;
    /* cmdline empty; id array left as zeros; extra_cmdline empty. */
}

/* Write a buffer to consecutive eMMC blocks. The buffer length
 * must be a multiple of the block size. Returns 0 on success or
 * the first failing call's error code. */
static int write_blocks(uint32_t start_lba, const uint8_t *buffer,
                        uint32_t byte_length)
{
    uint32_t blocks = byte_length / EMMC_BLOCK_SIZE;
    for (uint32_t i = 0; i < blocks; i++) {
        int r = emmc_write_block(start_lba + i,
                                 buffer + i * EMMC_BLOCK_SIZE);
        if (r != 0) {
            return r;
        }
    }
    return 0;
}

/* Round a byte count up to the next eMMC-block boundary. */
static uint32_t round_up_to_block(uint32_t bytes)
{
    return (bytes + EMMC_BLOCK_SIZE - 1) & ~(EMMC_BLOCK_SIZE - 1);
}

/* Verify the boot.img header we just wrote by reading the first
 * block of the boot partition back and comparing the first
 * eight bytes against the magic. A mismatch means the write
 * either did not land where we wanted, or landed but the eMMC
 * is reporting different bytes back — both are catastrophic and
 * the caller should not power-cycle the device until the
 * recovery story is clear. */
static int verify_boot_image_header(void)
{
    uint8_t verify_buf[EMMC_BLOCK_SIZE];
    int r = emmc_read_block(BOOT_PARTITION_LBA, verify_buf);
    if (r != 0) {
        debug_write("[boot-image] read-back failed\r\n");
        return r;
    }
    const char *expected = "ANDROID!";
    for (int i = 0; i < 8; i++) {
        if (verify_buf[i] != (uint8_t)expected[i]) {
            debug_write("[boot-image] read-back magic mismatch\r\n");
            return -1;
        }
    }
    return 0;
}

/* Public entry: write the running kernel image to the eMMC boot
 * partition wrapped in an Android boot.img header. Returns 0 on
 * success or non-zero on any failure. */
int write_kernel_to_emmc_boot_partition(void)
{
    debug_write("[boot-image] starting eMMC overwrite\r\n");

    /* Compute the kernel's on-disk size from the linker symbol. */
    uint32_t kernel_size_bytes =
        (uint32_t)((uintptr_t)__image_end - KERNEL_LOAD_ADDR);

    if (emmc_init() != 0) {
        debug_write("[boot-image] eMMC init failed\r\n");
        return -1;
    }

    /* Allocate one page for the boot.img header. */
    uint64_t header_page = alloc_page();
    if (header_page == 0) {
        debug_write("[boot-image] header page allocation failed\r\n");
        return -2;
    }
    uint8_t *header_buffer = (uint8_t *)(uintptr_t)header_page;
    build_boot_image_header(header_buffer, kernel_size_bytes);

    /* Write the header page first, then the kernel bytes. The
     * boot.img layout puts the kernel in the second page (at
     * page_size offset from the header). */
    debug_write("[boot-image] writing header...\r\n");
    if (write_blocks(BOOT_PARTITION_LBA, header_buffer,
                     BOOT_IMG_PAGE_SIZE) != 0) {
        debug_write("[boot-image] header write failed\r\n");
        return -3;
    }

    debug_write("[boot-image] writing kernel bytes...\r\n");
    uint32_t kernel_disk_size = round_up_to_block(kernel_size_bytes);
    if (write_blocks(BOOT_PARTITION_LBA + PAGE_BLOCKS,
                     (const uint8_t *)(uintptr_t)KERNEL_LOAD_ADDR,
                     kernel_disk_size) != 0) {
        debug_write("[boot-image] kernel write failed\r\n");
        return -4;
    }

    debug_write("[boot-image] verifying header magic...\r\n");
    if (verify_boot_image_header() != 0) {
        return -5;
    }

    debug_write("[boot-image] eMMC overwrite complete\r\n");
    return 0;
}
