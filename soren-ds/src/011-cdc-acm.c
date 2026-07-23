/*
 * 011-cdc-acm.c — CDC-ACM debug stream
 *
 * After the host completes enumeration and selects our
 * configuration, the kernel needs a way to surface text to the
 * developer's laptop. The CDC-ACM descriptors already promised the
 * host a virtual serial port (it shows up as `/dev/ttyACM0` on
 * Linux); this file makes the promise true by configuring the
 * bulk endpoints the descriptors named and exposing a `debug_write`
 * function the rest of the kernel calls when it wants to say
 * something.
 *
 * The two layers:
 *
 *   1. cdc_acm_init: configures the three CDC-ACM endpoints (the
 *      interrupt-notification endpoint and the two bulk endpoints)
 *      through the DWC3 per-endpoint command interface. Called
 *      from 010-usb-enumeration.c's control-transfer state machine
 *      when the SET_CONFIGURATION status stage completes.
 *
 *   2. debug_write: takes a NUL-terminated string, copies it into
 *      a staging buffer, posts a Normal TRB on the bulk-IN endpoint,
 *      and polls the controller's event ring until the transfer
 *      completes (or a generous loop budget runs out, so a
 *      disconnected host doesn't hang the kernel forever).
 *
 * The LED stage advances to STAGE_USB_ENUMERATED at the end of
 * cdc_acm_init so the developer can see at a glance that the host
 * has finished enumeration and the debug stream is live.
 */

#include <stdint.h>

extern uint64_t alloc_page(void);
extern void led_set_stage(int stage);

/* The SD-card debug log from 017-debug-log.c. `debug_write`
 * appends to that log on every call so the bring-up narration
 * survives even without a USB host attached. */
extern void debug_log_append(const char *text);

#define STAGE_USB_ENUMERATED 3

/* DWC3 registers and helpers we share with 010-usb-enumeration.c.
 * Phase 1's source tree deliberately avoids header files; we
 * extern-declare the shared bits here. Once the USB code is
 * substantial enough to deserve a header (probably issue 706's
 * USB mass-storage work), this duplication moves into a real
 * include file. */
/* DWC3 controller MMIO base — kept in sync with the same
 * constant in 009-usb.c and 010-usb-enumeration.c. Earlier
 * iterations of this file used 0xFEC00000, a stale Rockchip
 * BSP version's bus mapping; the actual address for this
 * device, per the device tree extracted from ROCKNIX, is
 * 0xFCC00000. See issue 109a. */
#define DWC3_BASE        0xFCC00000u
#define DWC3_DALEPENA    (DWC3_BASE + 0xC720u)
#define DWC3_GEVNTCOUNT  (DWC3_BASE + 0xC40Cu)

#define DEPCMD_DEPCFG      0x01u
#define DEPCMD_DEPXFERCFG  0x02u
#define DEPCMD_DEPSTRTXFER 0x06u

#define TRB_TYPE_NORMAL          1
#define TRB_CTRL_HWO   (1u << 0)
#define TRB_CTRL_LST   (1u << 1)
#define TRB_CTRL_IOC   (1u << 11)
#define TRB_CTRL_TYPE_SHIFT 4
#define TRB_CTRL_TYPE(t)    ((t) << TRB_CTRL_TYPE_SHIFT)

/* Physical endpoint numbers for the CDC-ACM endpoints. The DWC3
 * controller numbers endpoints physically as (logical_ep * 2 + dir)
 * where dir=0 for OUT and dir=1 for IN. So EP1 IN = 3, EP2 OUT = 4,
 * EP2 IN = 5. */
#define EP_NOTIFY 3
#define EP_BULK_OUT 4
#define EP_BULK_IN 5

#define EVT_IS_DEVICE_EVENT(e)   ((e) & 0x1u)
#define EVT_ENDPOINT_NUM(e)      (((e) >> 1) & 0x1Fu)
#define EVT_ENDPOINT_TYPE(e)     (((e) >> 6) & 0xFu)
#define EVT_EPTYPE_XFERCOMPLETE  1u

struct __attribute__((packed, aligned(16))) dwc3_trb {
    uint32_t buffer_ptr_lo;
    uint32_t buffer_ptr_hi;
    uint32_t size_pcm;
    uint32_t ctrl;
};

extern void depcmd_issue(unsigned ep, uint32_t cmd_with_params,
                         uint32_t par0, uint32_t par1, uint32_t par2);
extern void fill_trb(struct dwc3_trb *trb, uint64_t buffer_addr,
                     uint32_t size_bytes, unsigned trb_type);

static inline void mmio_write32(uintptr_t address, uint32_t value)
{
    *(volatile uint32_t *)address = value;
}

static inline uint32_t mmio_read32(uintptr_t address)
{
    return *(volatile uint32_t *)address;
}

/* Bulk-IN state. The TRB and the staging buffer come out of the
 * page allocator at init; staging is up to a page's worth (4 KB)
 * but each transfer is capped to the bulk endpoint's max packet
 * size because we don't yet handle multi-packet transfers from
 * here. */
static struct dwc3_trb *trb_bulk_in;
static uint8_t         *bulk_in_staging;
#define BULK_MAX_PACKET 64u

/* Bulk-OUT (host->device) state — the console READ path (issue 116).
 * `debug_write` narrates AT the developer; a chip-script (020-chips.c)
 * needs to hear back — a menu selection, a y/n verdict. The DWC3 receives
 * a host packet by DMA into a buffer a Normal TRB points at; on completion
 * it writes the untransferred residual into that TRB's size field, so
 * bytes_received = requested - residual. The OUT TRB shares the IN TRB's
 * page (a page holds 256 of them); the receive buffer is its own page.
 *
 * console_getchar hands bytes out one at a time, so a host packet carrying
 * several characters (a typed line arrives as one 64-byte OUT) is buffered
 * here and drained across calls rather than dropped after the first byte —
 * `rx_len` is how many landed, `rx_pos` how many we have handed back. */
static struct dwc3_trb *trb_bulk_out;
static uint8_t         *bulk_out_staging;
static uint32_t         rx_len;    /* bytes in the last completed packet   */
static uint32_t         rx_pos;    /* how many we have handed back so far   */
static int              rx_armed;  /* a receive TRB is posted, not yet done */

/* Read the event ring counter without dispatching events, watching for
 * an XferComplete on ONE named endpoint. Used both directions: the
 * bulk-IN path (debug_write) waits on EP_BULK_IN, the bulk-OUT path
 * (console_read) waits on EP_BULK_OUT. The full event dispatch lives in
 * 010-usb-enumeration.c's usb_poll; this helper just watches for the one
 * event we care about and acks the ring. Returns 0 on that completion,
 * -1 if the loop budget runs out — the escape hatch that keeps a
 * disconnected host (whose transfer never completes) from hanging the
 * kernel forever, the same budget debug_write has always relied on. */
static int wait_for_ep_xfer_complete(unsigned ep)
{
    extern uint64_t event_buffer_address;
    uint32_t budget = 1000000u;
    while (budget--) {
        uint32_t available = mmio_read32(DWC3_GEVNTCOUNT) & 0xFFFFu;
        if (available == 0) {
            continue;
        }
        uint32_t *events = (uint32_t *)(uintptr_t)event_buffer_address;
        uint32_t event_count = available / 4u;
        for (uint32_t i = 0; i < event_count; i++) {
            uint32_t event = events[i];
            if (!EVT_IS_DEVICE_EVENT(event)
                && EVT_ENDPOINT_NUM(event) == ep
                && EVT_ENDPOINT_TYPE(event) == EVT_EPTYPE_XFERCOMPLETE) {
                mmio_write32(DWC3_GEVNTCOUNT, available);
                return 0;
            }
        }
        mmio_write32(DWC3_GEVNTCOUNT, available);
    }
    return -1;
}

/* Configure one of the CDC endpoints. Bulk endpoints have type 2,
 * interrupt endpoints have type 3; max-packet for bulk in USB 2.0
 * high speed is 64 bytes (we already cap to it), and 16 for our
 * notification endpoint per the descriptor. */
static void configure_endpoint(unsigned ep, unsigned ep_type,
                               uint32_t max_packet)
{
    /* DEPCFG PAR0: max-packet at bits 22:30, ep-type at bits 1:2.
     * DEPCFG PAR1: ep number at bits 25:21, event mask bit 8. */
    uint32_t par0 = (max_packet << 22) | (ep_type << 1);
    uint32_t par1 = ((ep / 2) << 25) | (1u << 8);
    depcmd_issue(ep, DEPCMD_DEPCFG, par0, par1, 0);
    depcmd_issue(ep, DEPCMD_DEPXFERCFG, 1, 0, 0);
}

void cdc_acm_init(void)
{
    /* Allocate the bulk-IN TRB and the staging buffer. */
    uint64_t trb_page     = alloc_page();
    uint64_t staging_page = alloc_page();
    if (trb_page == 0 || staging_page == 0) {
        return;
    }
    trb_bulk_in     = (struct dwc3_trb *)(uintptr_t)trb_page;
    bulk_in_staging = (uint8_t *)(uintptr_t)staging_page;

    /* The bulk-OUT TRB shares the IN TRB's page (both are 16-byte
     * structures; a 4 KB page holds 256), so only the receive buffer
     * needs a fresh page. A failed alloc leaves trb_bulk_out NULL and
     * console_read stays a no-op — reads are best-effort, exactly as
     * writes are: a missing console must never wedge the kernel. */
    trb_bulk_out = trb_bulk_in + 1;
    uint64_t rx_page = alloc_page();
    bulk_out_staging = (rx_page != 0)
                     ? (uint8_t *)(uintptr_t)rx_page
                     : (uint8_t *)0;
    rx_len = 0;
    rx_pos = 0;

    /* Configure the three CDC endpoints. */
    configure_endpoint(EP_NOTIFY,   3, 16);
    configure_endpoint(EP_BULK_OUT, 2, 64);
    configure_endpoint(EP_BULK_IN,  2, 64);

    /* Enable them in DALEPENA, ORing onto whatever EP0 set. */
    uint32_t dalepena = mmio_read32(DWC3_DALEPENA);
    dalepena |= (1u << EP_NOTIFY) | (1u << EP_BULK_OUT) | (1u << EP_BULK_IN);
    mmio_write32(DWC3_DALEPENA, dalepena);

    /* Signal that enumeration is complete and the debug stream is
     * live. From this point on, debug_write can be called. */
    led_set_stage(STAGE_USB_ENUMERATED);
}

/* Copy bytes into the staging buffer up to a max-packet's worth.
 * Returns the number of bytes copied. */
static uint32_t stage_bytes(const char *text, uint32_t available)
{
    uint32_t copied = 0;
    while (copied < BULK_MAX_PACKET && copied < available) {
        bulk_in_staging[copied] = (uint8_t)text[copied];
        copied++;
    }
    return copied;
}

/* Count the length of a NUL-terminated string. The kernel doesn't
 * have a string library yet; phase 2 brings one up. */
static uint32_t cstring_length(const char *text)
{
    uint32_t n = 0;
    while (text[n] != 0) {
        n++;
    }
    return n;
}

void debug_write(const char *text)
{
    /* First fan-out: the SD-card debug log captures the bytes
     * regardless of whether a USB host is attached. */
    debug_log_append(text);

    if (trb_bulk_in == 0 || bulk_in_staging == 0) {
        /* cdc_acm_init has not run yet — no USB transfer
         * machinery to push bytes through. The SD log above has
         * already received the bytes if it is ready; this is
         * benign. */
        return;
    }
    uint32_t total = cstring_length(text);
    uint32_t sent = 0;
    while (sent < total) {
        uint32_t this_chunk = stage_bytes(text + sent, total - sent);
        fill_trb(trb_bulk_in,
                 (uint64_t)(uintptr_t)bulk_in_staging,
                 this_chunk,
                 TRB_TYPE_NORMAL);
        depcmd_issue(EP_BULK_IN, DEPCMD_DEPSTRTXFER,
                     (uint32_t)((uint64_t)(uintptr_t)trb_bulk_in >> 32),
                     (uint32_t)((uint64_t)(uintptr_t)trb_bulk_in & 0xFFFFFFFFu),
                     0);
        if (wait_for_ep_xfer_complete(EP_BULK_IN) != 0) {
            /* Host stopped reading or never connected. Drop the
             * remaining bytes silently. */
            return;
        }
        sent += this_chunk;
    }
}

/* {{{ console_getchar()
 *
 * The read half of the console (issue 116): block until the host sends a
 * byte and return it (0..255), or -1 if none arrived within the transfer
 * budget. This is the primitive every chip-script menu reads its selection
 * through.
 *
 * Exactly ONE receive transfer is ever outstanding. We arm a Normal TRB on
 * the bulk-OUT endpoint pointing at bulk_out_staging, then wait for its
 * completion. If the wait times out (the developer simply has not typed
 * yet), the TRB stays armed — `rx_armed` remembers that — and the next call
 * waits again on the SAME transfer rather than starting a second one, which
 * on a DWC3 endpoint that already has one active would be an error. A
 * caller that wants to block for a key loops while the return is < 0.
 *
 * When the transfer completes, the controller has DMA'd the host's bytes
 * into bulk_out_staging and written the UNTRANSFERRED residual into the
 * TRB's size field. The residual read must go through a volatile access:
 * fill_trb stored BULK_MAX_PACKET there and the compiler cannot see the
 * controller overwrite it, so a plain read could hand back the stale
 * request size. bytes_received = requested - residual. A packet can carry
 * several characters (a typed line arrives as one OUT), so we buffer the
 * whole packet and hand it out one byte per call before re-arming. */
int console_getchar(void)
{
    /* Still draining the last completed packet? Hand back the next byte. */
    if (rx_pos < rx_len) {
        return (int)bulk_out_staging[rx_pos++];
    }

    if (trb_bulk_out == 0 || bulk_out_staging == 0) {
        return -1;              /* cdc_acm_init has not run / alloc failed */
    }

    /* Arm a fresh receive only if the previous one already completed;
     * a timed-out transfer is still armed and must not be re-posted. */
    if (!rx_armed) {
        fill_trb(trb_bulk_out,
                 (uint64_t)(uintptr_t)bulk_out_staging,
                 BULK_MAX_PACKET,
                 TRB_TYPE_NORMAL);
        depcmd_issue(EP_BULK_OUT, DEPCMD_DEPSTRTXFER,
                     (uint32_t)((uint64_t)(uintptr_t)trb_bulk_out >> 32),
                     (uint32_t)((uint64_t)(uintptr_t)trb_bulk_out & 0xFFFFFFFFu),
                     0);
        rx_armed = 1;
    }

    if (wait_for_ep_xfer_complete(EP_BULK_OUT) != 0) {
        /* No key within the budget. Leave the transfer armed so the next
         * call resumes waiting on it — do NOT re-arm. */
        return -1;
    }
    rx_armed = 0;

    uint32_t residual =
        *(volatile uint32_t *)&trb_bulk_out->size_pcm & 0x00FFFFFFu;
    rx_len = (residual <= BULK_MAX_PACKET) ? (BULK_MAX_PACKET - residual) : 0;
    rx_pos = 0;
    if (rx_len == 0) {
        return -1;              /* a zero-length packet — nothing to hand back */
    }
    return (int)bulk_out_staging[rx_pos++];
}
/* }}} */

/* {{{ console_readline()
 *
 * Read a whole line into `buf` (issue 116): accumulate bytes from
 * console_getchar until Enter (CR or LF) or the buffer is one shy of full,
 * NUL-terminate, and return the length. Blocks for the developer to finish
 * the line — the intended semantics of "type something and press Enter";
 * a -1 from console_getchar (no key yet) is simply waited through. For a
 * single-key selection a menu reads console_getchar directly instead. */
uint32_t console_readline(char *buf, uint32_t max)
{
    uint32_t n = 0;
    if (max == 0) {
        return 0;
    }
    while (n + 1u < max) {
        int c = console_getchar();
        if (c < 0) {
            continue;           /* nothing typed yet — keep waiting */
        }
        if (c == '\r' || c == '\n') {
            break;
        }
        buf[n++] = (char)c;
    }
    buf[n] = 0;
    return n;
}
/* }}} */
