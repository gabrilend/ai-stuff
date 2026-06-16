/*
 * 014-emmc-probe.c — dump eMMC sectors to the CDC-ACM channel
 *
 * Before we can safely use the eMMC writer from 013-boot-image.c,
 * we need to confirm the boot-partition LBA the writer assumes is
 * the actual location of the boot partition on this specific
 * device. This file reads the first N sectors of the eMMC and
 * streams them out as hex through the debug channel from 110.
 * The developer captures the stream host-side and parses the GPT
 * (signature "EFI PART" at LBA 1) to find the real boot-partition
 * LBA, then updates the constant in 013-boot-image.c.
 *
 * The format is the conventional `xxd` layout — eight-digit hex
 * offset, two groups of eight bytes each in hex, an ASCII
 * fallback at the right margin. A host script can re-assemble
 * the original bytes from this format with no ambiguity.
 *
 * This file is small and one-shot. It exists for safety: as long
 * as it is in the build and called from kernel_main, the project
 * is forced to confirm the eMMC layout before the next eMMC
 * write happens.
 */

#include <stdint.h>

extern int  emmc_read_block(uint32_t lba, uint8_t *buffer);
extern void debug_write(const char *text);
extern uint64_t alloc_page(void);

static const char hex_chars[] = "0123456789ABCDEF";

/* Compose a byte's two hex digits at the given buffer position. */
static void byte_to_hex(uint8_t b, char *out)
{
    out[0] = hex_chars[(b >> 4) & 0xF];
    out[1] = hex_chars[b & 0xF];
}

/* Compose a 32-bit value as eight hex digits. */
static void u32_to_hex(uint32_t v, char *out)
{
    byte_to_hex((uint8_t)(v >> 24), out + 0);
    byte_to_hex((uint8_t)(v >> 16), out + 2);
    byte_to_hex((uint8_t)(v >> 8),  out + 4);
    byte_to_hex((uint8_t)(v),       out + 6);
}

/* Dump a single 512-byte sector through the debug channel. Each
 * sector turns into 32 lines of 16 bytes — about 1.2 KB of text
 * over the wire. */
static void dump_sector(uint32_t lba, const uint8_t *buffer)
{
    /* Sector header line: "SECTOR 00000000:" followed by the LBA
     * in hex, then a newline. */
    char header[32];
    header[0] = 'S'; header[1] = 'E'; header[2] = 'C';
    header[3] = 'T'; header[4] = 'O'; header[5] = 'R';
    header[6] = ' ';
    u32_to_hex(lba, header + 7);
    header[15] = ':';
    header[16] = '\r';
    header[17] = '\n';
    header[18] = 0;
    debug_write(header);

    /* Body lines: 32 rows of 16 bytes each.
     * Format: "00000000: AA BB CC DD EE FF 11 22  33 44 55 66 77 88 99 00  |ASCII|" */
    char line[80];
    for (uint32_t row = 0; row < 32; row++) {
        uint32_t offset = row * 16;
        u32_to_hex(offset, line);
        line[8] = ':';
        line[9] = ' ';
        /* Sixteen bytes in two columns of eight, separated by a
         * second space at position 10 + 8*3 = 34. */
        uint32_t pos = 10;
        for (uint32_t col = 0; col < 16; col++) {
            byte_to_hex(buffer[offset + col], line + pos);
            line[pos + 2] = ' ';
            pos += 3;
            if (col == 7) {
                line[pos] = ' ';
                pos++;
            }
        }
        /* ASCII fallback column. */
        line[pos] = '|';
        pos++;
        for (uint32_t col = 0; col < 16; col++) {
            uint8_t b = buffer[offset + col];
            line[pos] = (b >= 0x20 && b < 0x7F) ? (char)b : '.';
            pos++;
        }
        line[pos] = '|';
        pos++;
        line[pos] = '\r';
        pos++;
        line[pos] = '\n';
        pos++;
        line[pos] = 0;
        debug_write(line);
    }
}

void emmc_dump_to_debug(uint32_t start_lba, uint32_t count)
{
    debug_write("\r\n[emmc-probe] starting dump\r\n");

    /* Allocate one page for the read buffer. We read one sector
     * at a time, dump it, and re-use the buffer for the next. */
    uint64_t buf_page = alloc_page();
    if (buf_page == 0) {
        debug_write("[emmc-probe] buffer page allocation failed\r\n");
        return;
    }
    uint8_t *buffer = (uint8_t *)(uintptr_t)buf_page;

    for (uint32_t i = 0; i < count; i++) {
        if (emmc_read_block(start_lba + i, buffer) != 0) {
            debug_write("[emmc-probe] read failed; aborting\r\n");
            return;
        }
        dump_sector(start_lba + i, buffer);
    }

    debug_write("[emmc-probe] dump complete\r\n");
}
