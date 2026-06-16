/*
 * 016-emmc-backup.c — copy eMMC sectors to the microSD card
 *
 * The safety gate from issue 110e: before the eMMC writer in
 * 110b is allowed to write to the real eMMC's boot partition,
 * we need to confirm the partition's actual LBA against the
 * eMMC's GPT. The dump goes to the external microSD card —
 * never to a USB-C-connected host machine — so the threat model
 * the project committed to during issue 101 stays intact.
 *
 * The function reads N sectors from the eMMC starting at one
 * LBA and writes them to the microSD starting at another LBA.
 * Both controllers are already brought up by the time this is
 * called.
 *
 * Progress is narrated through the CDC-ACM debug stream — the
 * narration is text, low volume, and only carries "we're on
 * sector X of N," not the dump itself. The dump itself stays
 * on the microSD card.
 */

#include <stdint.h>

extern int  emmc_read_block(uint32_t lba, uint8_t *buffer);
extern int  sd_write_block(uint32_t lba, const uint8_t *buffer);
extern void debug_write(const char *text);
extern uint64_t alloc_page(void);
extern void led_heartbeat(void);

int emmc_backup_to_sd(uint32_t emmc_start_lba,
                      uint32_t sd_start_lba,
                      uint32_t sector_count)
{
    debug_write("[backup] eMMC-to-SD backup starting\r\n");

    /* Allocate a 512-byte buffer. We re-use it for every
     * sector — read into it from eMMC, write it out to SD,
     * repeat. */
    uint64_t buf_page = alloc_page();
    if (buf_page == 0) {
        debug_write("[backup] buffer allocation failed\r\n");
        return -1;
    }
    uint8_t *buffer = (uint8_t *)(uintptr_t)buf_page;

    for (uint32_t i = 0; i < sector_count; i++) {
        if (emmc_read_block(emmc_start_lba + i, buffer) != 0) {
            debug_write("[backup] eMMC read failed\r\n");
            return -2;
        }
        if (sd_write_block(sd_start_lba + i, buffer) != 0) {
            debug_write("[backup] SD write failed\r\n");
            return -3;
        }
        /* Narrate roughly every ten megabytes of progress and
         * advance the heartbeat by one step. Ten megabytes is
         * 20,480 sectors (5 * 4096) — not a power of two, so the
         * cadence check uses an explicit modulo rather than the
         * bitmask the prior one-megabyte cadence used. At the
         * chip's currently-slow boot clock the slower cadence
         * keeps the debug-log noise manageable; the bottom amber
         * LED blinks visibly but not frantically across the
         * multi-minute backup. */
        if ((i % 20480u) == 0) {
            debug_write("[backup] progress...\r\n");
            led_heartbeat();
        }
    }

    debug_write("[backup] complete\r\n");
    return 0;
}
