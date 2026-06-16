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

#define STAGE_USB_ENUMERATED 3

/* DWC3 registers and helpers we share with 010-usb-enumeration.c.
 * Phase 1's source tree deliberately avoids header files; we
 * extern-declare the shared bits here. Once the USB code is
 * substantial enough to deserve a header (probably issue 706's
 * USB mass-storage work), this duplication moves into a real
 * include file. */
#define DWC3_BASE        0xFEC00000u
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

/* Read the event ring counter without dispatching events. We use
 * this to know when a posted bulk-IN TRB has completed. The full
 * event dispatch lives in 010-usb-enumeration.c's usb_poll; this
 * helper just watches for the specific event we care about. */
static int wait_for_bulk_in_complete(void)
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
                && EVT_ENDPOINT_NUM(event) == EP_BULK_IN
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
    if (trb_bulk_in == 0 || bulk_in_staging == 0) {
        /* cdc_acm_init has not run yet — no transfer machinery to
         * push bytes through. The caller may be wired in too
         * early; for phase 1 this is benign (debug_write before
         * enumeration is a no-op). */
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
        if (wait_for_bulk_in_complete() != 0) {
            /* Host stopped reading or never connected. Drop the
             * remaining bytes silently. */
            return;
        }
        sent += this_chunk;
    }
}
