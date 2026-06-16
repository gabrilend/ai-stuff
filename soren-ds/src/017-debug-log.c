/*
 * 017-debug-log.c — SD-card-backed debug log
 *
 * Phase 1's threat model rules out connecting the device to any
 * host with data worth losing over USB-C until the eMMC is fully
 * under our code. The existing `debug_write` in 011-cdc-acm.c
 * sends text through the bulk-IN endpoint, which drops silently
 * when no host is attached — exactly the case during the first
 * hardware boot. Without diagnostic visibility, a bring-up
 * failure leaves the developer with only the LED stages to
 * decode "what happened," and the LED stages collapse every
 * failure mode into one or two patterns.
 *
 * This file gives us a second diagnostic channel: a ring buffer
 * in DRAM that captures every `debug_write` call, and a periodic
 * flush function that writes the buffer to a reserved region of
 * the microSD card. After the SD card is pulled from the device
 * and read on a separate machine via raw `dd` (no mount, no
 * execution path), the log file is plain text.
 *
 * The threat model stays intact: the device wrote bytes to a
 * removable card, the host machine reads those bytes through a
 * raw block-device copy. At no point does the device touch the
 * trusted machine through an active bus.
 *
 * What is deliberately scoped down:
 *
 *   - No timestamps. Phase 1 has no timer source.
 *   - No log levels. Every call is the same priority.
 *   - No rotation policy beyond "wrap when we hit the region end."
 *   - No format strings. Caller passes a pre-formatted string.
 *
 * Long term, this file is supposed to go away — the soramech
 * runtime's RAM transcript ring from phase 3 issue
 * `310-ram-transcript-ring.md` is the right home for diagnostic
 * event capture, and it stays in RAM (no SD wear). 310 already
 * references this issue and tracks its removal.
 */

#include <stdint.h>

extern int sd_write_block(uint32_t lba, const uint8_t *buffer);

/* Buffer sizes and SD region. */
#define LOG_BUFFER_SIZE        4096u    /* one page = 8 SD blocks */
#define LOG_BUFFER_BLOCKS      (LOG_BUFFER_SIZE / 512u)
#define LOG_FLUSH_THRESHOLD    3072u    /* flush at 75% full */
#define LOG_SD_REGION_START    0x4000000u  /* LBA ~2 GB into the SD card */
#define LOG_SD_REGION_SIZE     32768u   /* 16 MB / 512 B per block */

/* Buffer state. All accessed from kernel_main's single thread —
 * no concurrency to worry about until phase 2. */
static uint8_t *log_buffer;
static uint32_t log_buffer_pos;
static uint32_t log_sd_next_lba;
static int      log_ready;

/* Static .bss-resident buffer for the ring.
 *
 * Earlier versions of this file allocated the buffer from the page
 * allocator at debug_log_init time. The "best-effort" disposition
 * (if alloc_page returns zero, leave the log disabled) silently
 * cost us our only post-boot diagnostic channel during a phase-1
 * hardware test: the kernel reached the panic-stage signal but the
 * SD-backed log region read back as 0xFF for sixteen megabytes,
 * indicating that nothing had ever been written there. The most
 * likely cause was alloc_page returning zero in debug_log_init for
 * a reason we could not see (because the channel that would tell
 * us why was the channel that just disabled itself).
 *
 * A static buffer takes alloc_page out of the bring-up sequence
 * entirely. The buffer is always present in .bss; debug_log_init
 * cannot fail to allocate it. The cost is one page of memory
 * permanently reserved for the log even when no debug_write
 * happens; the cost-benefit there is overwhelming given that this
 * is the only diagnostic channel until soramech's RAM transcript
 * ring lands in phase 3 (issue 310).
 */
static uint8_t log_static_buffer[LOG_BUFFER_SIZE];

static void zero_buffer(void)
{
    for (uint32_t i = 0; i < LOG_BUFFER_SIZE; i++) {
        log_buffer[i] = 0;
    }
}

/* Set up the ring buffer pointers. Called from kernel_main after
 * sd_init succeeds. Cannot fail — the buffer is statically
 * reserved. */
void debug_log_init(void)
{
    if (log_ready) {
        return;
    }
    log_buffer = log_static_buffer;
    log_buffer_pos = 0;
    log_sd_next_lba = LOG_SD_REGION_START;
    zero_buffer();
    log_ready = 1;
}

/* Write the full buffer (8 SD blocks) to the next region on the
 * SD card and reset the buffer position. The buffer's tail bytes
 * may be zero (the most recent flush left them so) — fine, they
 * read as null bytes in the eventual dump and don't affect the
 * text content. */
static void flush_to_sd(void)
{
    if (!log_ready) {
        return;
    }
    /* Wrap if we've reached the end of the region. */
    if (log_sd_next_lba + LOG_BUFFER_BLOCKS
        > LOG_SD_REGION_START + LOG_SD_REGION_SIZE) {
        log_sd_next_lba = LOG_SD_REGION_START;
    }
    for (uint32_t i = 0; i < LOG_BUFFER_BLOCKS; i++) {
        /* If the write fails, we silently drop this chunk and move
         * on — diagnostic best-effort, don't block forward
         * progress on a failed log write. */
        sd_write_block(log_sd_next_lba + i,
                       log_buffer + (i * 512u));
    }
    log_sd_next_lba += LOG_BUFFER_BLOCKS;
    zero_buffer();
    log_buffer_pos = 0;
}

/* Append a NUL-terminated string to the ring buffer. If appending
 * would overflow, flush first and then continue. */
void debug_log_append(const char *text)
{
    if (!log_ready) {
        return;
    }
    uint32_t i = 0;
    while (text[i] != 0) {
        if (log_buffer_pos >= LOG_BUFFER_SIZE) {
            flush_to_sd();
        }
        log_buffer[log_buffer_pos++] = (uint8_t)text[i++];
    }
    if (log_buffer_pos >= LOG_FLUSH_THRESHOLD) {
        flush_to_sd();
    }
}

/* Force a flush regardless of threshold — called from kernel_main
 * after the eMMC backup completes, so the last buffer is on the
 * card before STAGE_BACKUP_COMPLETE lights up. */
void debug_log_flush(void)
{
    if (!log_ready) {
        return;
    }
    if (log_buffer_pos > 0) {
        flush_to_sd();
    }
}
