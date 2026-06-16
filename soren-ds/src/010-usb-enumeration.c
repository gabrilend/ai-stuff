/*
 * 010-usb-enumeration.c — USB device enumeration over endpoint zero
 *
 * Sits on top of the DWC3 controller bring-up from 009-usb.c and
 * makes the device say its own name when a host asks. The host
 * (a laptop running Linux, macOS, or Windows) sends a documented
 * sequence of control transfers to endpoint zero immediately after
 * USB bus reset, expecting answers that identify the device's
 * vendor and product. Without this file, the host receives no
 * answers, times out, and decides nothing useful is plugged in;
 * with this file, `lsusb` on the host shows the device with our
 * vendor and product IDs and the project's name strings.
 *
 * The work splits into three layers.
 *
 *   1. The descriptor tables — small, byte-exact data structures
 *      defined by the USB 2.0 specification that the host expects
 *      back from GET_DESCRIPTOR requests. These live in .rodata
 *      because they never change at runtime.
 *
 *   2. The endpoint-zero hardware bring-up — DWC3-specific commands
 *      that allocate transfer resources for the control endpoint
 *      and turn the controller's RUN bit on. After this step the
 *      controller can receive setup packets from the host and post
 *      them into its event ring.
 *
 *   3. The control-transfer dispatch — a polling loop that watches
 *      the event ring for setup-packet events, parses each setup
 *      packet's eight-byte header, and either returns descriptor
 *      bytes (for GET_DESCRIPTOR) or applies state changes (for
 *      SET_ADDRESS, SET_CONFIGURATION).
 *
 * The DWC3-specific register addresses and field positions come
 * from the Linux DWC3 gadget driver in
 * drivers/usb/dwc3/{core.h, gadget.c}. The control-transfer
 * dispatch follows the USB 2.0 spec chapter 9 directly.
 *
 * What is deliberately not here yet:
 *   - CDC-ACM-specific descriptors and endpoints. Issue 110 layers
 *     CDC-ACM on top of the vendor-class device we present here.
 *   - Multi-packet descriptor handling beyond what fits in a single
 *     64-byte EP0 transfer. The configuration descriptor with the
 *     CDC-ACM interfaces will exceed 64 bytes; 110 deals with
 *     multi-packet IN transfers when it adds the interfaces.
 *   - Interrupt-driven event handling. Phase 1 polls because the
 *     kernel has nothing else to do during enumeration.
 *   - Suspend/resume, remote wake, and the rest of the USB power
 *     management surface. Phase 9's app lifecycle work covers the
 *     wake side; nothing earlier needs the rest.
 */

#include <stdint.h>

extern uint64_t alloc_page(void);

/* The vendor and product IDs we picked.
 *
 * 0x1209 is the InterBiometrics / pid.codes development pool — a
 * vendor block specifically reserved for open hardware and
 * development projects that have not paid the USB-IF for an
 * assigned vendor ID. Using a value from this block makes our
 * device unambiguous on any developer's machine without paying
 * for an official ID we don't need.
 *
 * The product ID is project-specific. If we ever ship to anyone
 * else, we apply to pid.codes for a real assignment and update
 * this constant. */
#define USB_VENDOR_ID   0x1209u
#define USB_PRODUCT_ID  0x5050u

/* String descriptor indices. Zero is reserved for the language ID
 * table; the host asks for it first to learn which languages the
 * device offers. */
#define STR_INDEX_LANG          0
#define STR_INDEX_MANUFACTURER  1
#define STR_INDEX_PRODUCT       2
#define STR_INDEX_SERIAL        3

/* USB descriptor types from chapter 9 of the spec. */
#define USB_DT_DEVICE        0x01
#define USB_DT_CONFIGURATION 0x02
#define USB_DT_STRING        0x03
#define USB_DT_INTERFACE     0x04

/* Standard USB request codes (bRequest field in setup packet). */
#define USB_REQ_GET_STATUS         0x00
#define USB_REQ_CLEAR_FEATURE      0x01
#define USB_REQ_SET_FEATURE        0x03
#define USB_REQ_SET_ADDRESS        0x05
#define USB_REQ_GET_DESCRIPTOR     0x06
#define USB_REQ_SET_DESCRIPTOR     0x07
#define USB_REQ_GET_CONFIGURATION  0x08
#define USB_REQ_SET_CONFIGURATION  0x09

/* ==========================================================================
 * Descriptor tables — read-only, byte-exact per USB 2.0 spec.
 * ========================================================================== */

/* USB device descriptor. Section 9.6.1 of the spec.
 * Total length: 18 bytes. */
struct __attribute__((packed)) usb_device_descriptor {
    uint8_t  bLength;             /* 18 */
    uint8_t  bDescriptorType;     /* USB_DT_DEVICE */
    uint16_t bcdUSB;              /* USB 2.0 = 0x0200 */
    uint8_t  bDeviceClass;        /* 0 = defined at interface level */
    uint8_t  bDeviceSubClass;     /* 0 */
    uint8_t  bDeviceProtocol;     /* 0 */
    uint8_t  bMaxPacketSize0;     /* 64 bytes for EP0 on high speed */
    uint16_t idVendor;            /* USB_VENDOR_ID */
    uint16_t idProduct;           /* USB_PRODUCT_ID */
    uint16_t bcdDevice;           /* device release in BCD */
    uint8_t  iManufacturer;       /* string index */
    uint8_t  iProduct;            /* string index */
    uint8_t  iSerialNumber;       /* string index */
    uint8_t  bNumConfigurations;  /* 1 */
};

static const struct usb_device_descriptor device_descriptor = {
    .bLength            = sizeof(struct usb_device_descriptor),
    .bDescriptorType    = USB_DT_DEVICE,
    .bcdUSB             = 0x0200,
    .bDeviceClass       = 0,
    .bDeviceSubClass    = 0,
    .bDeviceProtocol    = 0,
    .bMaxPacketSize0    = 64,
    .idVendor           = USB_VENDOR_ID,
    .idProduct          = USB_PRODUCT_ID,
    .bcdDevice          = 0x0100,
    .iManufacturer      = STR_INDEX_MANUFACTURER,
    .iProduct           = STR_INDEX_PRODUCT,
    .iSerialNumber      = STR_INDEX_SERIAL,
    .bNumConfigurations = 1,
};

/* USB configuration descriptor + interface descriptor, concatenated.
 * The host asks for the whole configuration tree in one transfer;
 * we return the full block. Section 9.6.3 / 9.6.5 of the spec.
 *
 * Phase 1's interface is vendor-defined (class FF) with zero
 * endpoints besides EP0. Issue 110 adds the CDC-ACM interface
 * with its bulk endpoints. */
struct __attribute__((packed)) usb_full_config {
    /* Configuration descriptor — 9 bytes. */
    uint8_t  cfg_bLength;
    uint8_t  cfg_bDescriptorType;     /* USB_DT_CONFIGURATION */
    uint16_t cfg_wTotalLength;        /* total bytes of this struct */
    uint8_t  cfg_bNumInterfaces;      /* 1 */
    uint8_t  cfg_bConfigurationValue; /* 1 */
    uint8_t  cfg_iConfiguration;      /* 0 (no string) */
    uint8_t  cfg_bmAttributes;        /* 0x80 = bus-powered */
    uint8_t  cfg_bMaxPower;           /* in 2 mA units */

    /* Interface descriptor — 9 bytes. */
    uint8_t  if_bLength;
    uint8_t  if_bDescriptorType;      /* USB_DT_INTERFACE */
    uint8_t  if_bInterfaceNumber;     /* 0 */
    uint8_t  if_bAlternateSetting;    /* 0 */
    uint8_t  if_bNumEndpoints;        /* 0 (we only use EP0) */
    uint8_t  if_bInterfaceClass;      /* 0xFF = vendor-defined */
    uint8_t  if_bInterfaceSubClass;   /* 0 */
    uint8_t  if_bInterfaceProtocol;   /* 0 */
    uint8_t  if_iInterface;           /* 0 (no string) */
};

static const struct usb_full_config full_config = {
    .cfg_bLength             = 9,
    .cfg_bDescriptorType     = USB_DT_CONFIGURATION,
    .cfg_wTotalLength        = sizeof(struct usb_full_config),
    .cfg_bNumInterfaces      = 1,
    .cfg_bConfigurationValue = 1,
    .cfg_iConfiguration      = 0,
    .cfg_bmAttributes        = 0x80,
    .cfg_bMaxPower           = 100,  /* 200 mA */

    .if_bLength            = 9,
    .if_bDescriptorType    = USB_DT_INTERFACE,
    .if_bInterfaceNumber   = 0,
    .if_bAlternateSetting  = 0,
    .if_bNumEndpoints      = 0,
    .if_bInterfaceClass    = 0xFF,
    .if_bInterfaceSubClass = 0,
    .if_bInterfaceProtocol = 0,
    .if_iInterface         = 0,
};

/* String descriptors. USB strings are UTF-16 little-endian, with a
 * two-byte header (bLength, bDescriptorType=STRING) before the
 * UTF-16 payload. The language-table descriptor at index 0 carries
 * a list of supported language IDs; we declare US English (0x0409)
 * as our only language.
 *
 * Each string descriptor is small enough to fit in a single 64-byte
 * EP0 transfer; we never have to deal with multi-packet IN. */

static const uint8_t str_lang[] = {
    4, USB_DT_STRING, 0x09, 0x04,  /* langid = 0x0409 (en-US) */
};

/* "Soren DS Project" — 16 characters → 32 bytes UTF-16 + 2 header. */
static const uint8_t str_manufacturer[] = {
    34, USB_DT_STRING,
    'S', 0, 'o', 0, 'r', 0, 'e', 0, 'n', 0, ' ', 0,
    'D', 0, 'S', 0, ' ', 0,
    'P', 0, 'r', 0, 'o', 0, 'j', 0, 'e', 0, 'c', 0, 't', 0,
};

/* "Soren DS" — 8 characters → 16 bytes UTF-16 + 2 header. */
static const uint8_t str_product[] = {
    18, USB_DT_STRING,
    'S', 0, 'o', 0, 'r', 0, 'e', 0, 'n', 0, ' ', 0,
    'D', 0, 'S', 0,
};

/* Serial number — "0000000001" placeholder. 10 chars → 20 bytes
 * UTF-16 + 2 header. A future issue can generate a per-device
 * serial from a stable hash of the eMMC's CID or similar. */
static const uint8_t str_serial[] = {
    22, USB_DT_STRING,
    '0', 0, '0', 0, '0', 0, '0', 0, '0', 0,
    '0', 0, '0', 0, '0', 0, '0', 0, '1', 0,
};

/* Look up a string descriptor by index. Returns a pointer to the
 * descriptor bytes and writes its length through the out pointer,
 * or returns NULL for an unknown index. */
static const uint8_t *string_descriptor(uint8_t index, uint8_t *length)
{
    switch (index) {
        case STR_INDEX_LANG:
            *length = sizeof(str_lang);
            return str_lang;
        case STR_INDEX_MANUFACTURER:
            *length = sizeof(str_manufacturer);
            return str_manufacturer;
        case STR_INDEX_PRODUCT:
            *length = sizeof(str_product);
            return str_product;
        case STR_INDEX_SERIAL:
            *length = sizeof(str_serial);
            return str_serial;
        default:
            *length = 0;
            return (const uint8_t *)0;
    }
}

/* ==========================================================================
 * Setup packet — the 8-byte header every control transfer starts with.
 * ========================================================================== */

struct __attribute__((packed)) usb_setup_packet {
    uint8_t  bmRequestType;
    uint8_t  bRequest;
    uint16_t wValue;
    uint16_t wIndex;
    uint16_t wLength;
};

/* Decode wValue into descriptor type (upper byte) and index (lower). */
static inline uint8_t setup_descriptor_type(const struct usb_setup_packet *s)
{
    return (uint8_t)(s->wValue >> 8);
}

static inline uint8_t setup_descriptor_index(const struct usb_setup_packet *s)
{
    return (uint8_t)(s->wValue & 0xFF);
}

/* ==========================================================================
 * DWC3 register access for endpoint-zero bring-up.
 *
 * The base addresses and field positions come from the DWC3 driver
 * in the Linux kernel; specifically core.h for offsets and gadget.c
 * for the bring-up order. Values here are based on the spec as
 * documented, but the DWC3 endpoint-command parameter layout is
 * fiddly enough that real hardware testing will likely surface
 * small corrections.
 * ========================================================================== */

#define DWC3_BASE        0xFEC00000u
#define DWC3_DCTL        (DWC3_BASE + 0xC704u)
#define DWC3_DALEPENA    (DWC3_BASE + 0xC720u)
#define DWC3_GEVNTADRLO  (DWC3_BASE + 0xC400u)
#define DWC3_GEVNTADRHI  (DWC3_BASE + 0xC404u)
#define DWC3_GEVNTSIZ    (DWC3_BASE + 0xC408u)
#define DWC3_GEVNTCOUNT  (DWC3_BASE + 0xC40Cu)

/* Per-endpoint command registers. DWC3 numbers endpoints as
 * (physical_ep_number) where ep0out=0 and ep0in=1. The command
 * registers are spaced 0x10 bytes apart. */
#define DWC3_DEPCMDPAR2(n) (DWC3_BASE + 0xC800u + ((n) * 0x10u))
#define DWC3_DEPCMDPAR1(n) (DWC3_BASE + 0xC804u + ((n) * 0x10u))
#define DWC3_DEPCMDPAR0(n) (DWC3_BASE + 0xC808u + ((n) * 0x10u))
#define DWC3_DEPCMD(n)     (DWC3_BASE + 0xC80Cu + ((n) * 0x10u))

#define DCTL_RUN_STOP    (1u << 31)

#define DEPCMD_CMDACT    (1u << 10)
#define DEPCMD_DEPSTARTCFG 0x09u
#define DEPCMD_DEPCFG    0x01u
#define DEPCMD_DEPXFERCFG 0x02u
#define DEPCMD_DEPSTRTXFER 0x06u

/* DCFG register: bits 6:0 carry the device address that the host
 * assigns to us during enumeration. The page allocator never
 * touches this register, but the SET_ADDRESS handler in this file
 * writes it after the status stage. */
#define DWC3_DCFG        (DWC3_BASE + 0xC700u)
#define DCFG_DEVADDR_SHIFT 3
#define DCFG_DEVADDR_MASK  (0x7Fu << DCFG_DEVADDR_SHIFT)

#define EP0OUT 0
#define EP0IN  1

/* ==========================================================================
 * Transfer Request Block (TRB) — the controller-readable descriptor
 * that tells the DWC3 controller "transfer these bytes." Each TRB is
 * 16 bytes. The controller walks a ring of TRBs as the host drives
 * transfers; we use a single-TRB ring per endpoint here because
 * control transfers are inherently sequential.
 *
 * Layout per the DWC3 documentation:
 *   bytes 0..7  : 64-bit buffer physical address
 *   bytes 8..11 : 32-bit field with the buffer size in bits 23:0 and
 *                 a packet-count metadata field in bits 30:24
 *   bytes 12..15: 32-bit control word with the TRB type (bits 9:4),
 *                 the HWO bit (bit 0 — hardware owns this entry),
 *                 the LST bit (bit 1 — this is the last TRB of a
 *                 chain), the IOC bit (bit 11 — interrupt on
 *                 completion so we get an event), and the CHN bit
 *                 (bit 2 — chain with the next TRB; we never chain).
 * ========================================================================== */

struct __attribute__((packed, aligned(16))) dwc3_trb {
    uint32_t buffer_ptr_lo;   /* bits 31:0  of buffer physical address */
    uint32_t buffer_ptr_hi;   /* bits 63:32 of buffer physical address */
    uint32_t size_pcm;        /* size in bytes (bits 23:0) + PCM1 */
    uint32_t ctrl;            /* type, HWO, LST, IOC, etc. */
};

/* TRB control-word bit positions. */
#define TRB_CTRL_HWO          (1u << 0)
#define TRB_CTRL_LST          (1u << 1)
#define TRB_CTRL_CHN          (1u << 2)
#define TRB_CTRL_IOC          (1u << 11)
#define TRB_CTRL_TYPE_SHIFT   4
#define TRB_CTRL_TYPE(t)      ((t) << TRB_CTRL_TYPE_SHIFT)

/* TRB types per DWC3 documentation. */
#define TRB_TYPE_NORMAL          1
#define TRB_TYPE_CONTROL_SETUP   2
#define TRB_TYPE_CONTROL_STATUS2 3
#define TRB_TYPE_CONTROL_STATUS3 4
#define TRB_TYPE_CONTROL_DATA    5

/* ==========================================================================
 * DWC3 event encoding — what the controller writes into the event
 * buffer when something interesting happens on the bus.
 *
 * Each event is 4 bytes. The low bit distinguishes endpoint events
 * (bit 0 = 0) from device events (bit 0 = 1). For endpoint events,
 * bits 5:1 carry the endpoint number; bits 9:6 carry the endpoint-
 * event-type code. We care about XferComplete (type code 1), which
 * fires when a TRB we posted finishes (either because the host
 * delivered data into a buffer we pre-armed, or because we
 * delivered data into a buffer the host posted).
 *
 * Device events have their type code in bits 11:8. The codes are
 * sparsely documented; for phase 1 we only react to "bus reset"
 * and "connection done" (both can be safely treated as "re-arm
 * EP0 OUT for setup-packet receive").
 * ========================================================================== */

#define EVT_IS_DEVICE_EVENT(e)      ((e) & 0x1u)
#define EVT_ENDPOINT_NUM(e)         (((e) >> 1) & 0x1Fu)
#define EVT_ENDPOINT_TYPE(e)        (((e) >> 6) & 0xFu)
#define EVT_DEVICE_TYPE(e)          (((e) >> 8) & 0xFu)

#define EVT_EPTYPE_XFERCOMPLETE     1u
#define EVT_DEVTYPE_DISCONNECT      0u
#define EVT_DEVTYPE_USBRESET        1u
#define EVT_DEVTYPE_CONNECTDONE     2u

static inline void mmio_write32(uintptr_t address, uint32_t value)
{
    *(volatile uint32_t *)address = value;
}

static inline uint32_t mmio_read32(uintptr_t address)
{
    return *(volatile uint32_t *)address;
}

/* Issue a DEPCMD and spin until the hardware clears CMDACT. */
static void depcmd_issue(unsigned ep, uint32_t cmd_with_params,
                         uint32_t par0, uint32_t par1, uint32_t par2)
{
    mmio_write32(DWC3_DEPCMDPAR2(ep), par2);
    mmio_write32(DWC3_DEPCMDPAR1(ep), par1);
    mmio_write32(DWC3_DEPCMDPAR0(ep), par0);
    mmio_write32(DWC3_DEPCMD(ep), cmd_with_params | DEPCMD_CMDACT);
    while (mmio_read32(DWC3_DEPCMD(ep)) & DEPCMD_CMDACT) {
        /* Spin; the command completes within microseconds. */
    }
}

/* Per-endpoint TRBs and the setup-packet buffer.
 *
 * The DWC3 controller wants TRBs at 16-byte-aligned DMA addresses.
 * The setup-packet buffer needs to hold 8 bytes the controller
 * DMAs into when the host sends a setup packet. We give each of
 * these its own page from the allocator — wasteful at 4 KB per
 * 16-byte TRB, but the alignment is right and the bookkeeping is
 * trivial. */
static struct dwc3_trb *trb_ep0_out;
static struct dwc3_trb *trb_ep0_in;
static uint8_t         *setup_buffer;

static uint64_t event_buffer_address;
#define EVENT_BUFFER_SIZE 4096u

/* Helpers to fill a TRB for each of the transfer types we use. The
 * TRBs always have IOC set so the controller writes an event to
 * notify us when they complete; HWO is the last bit set so the
 * controller does not pick the TRB up mid-update. */
static void fill_trb(struct dwc3_trb *trb, uint64_t buffer_addr,
                     uint32_t size_bytes, unsigned trb_type)
{
    trb->buffer_ptr_lo = (uint32_t)(buffer_addr & 0xFFFFFFFFu);
    trb->buffer_ptr_hi = (uint32_t)(buffer_addr >> 32);
    trb->size_pcm = size_bytes & 0x00FFFFFFu;
    /* Write the control word last so the HWO bit only goes high
     * after the other fields are populated. */
    trb->ctrl = TRB_CTRL_TYPE(trb_type)
              | TRB_CTRL_LST
              | TRB_CTRL_IOC
              | TRB_CTRL_HWO;
}

/* Issue DEPSTRTXFER on an endpoint, telling the controller to
 * begin processing the TRB at the provided address. */
static void depcmd_start_xfer(unsigned ep, uint64_t trb_addr)
{
    uint32_t par0 = (uint32_t)(trb_addr >> 32);
    uint32_t par1 = (uint32_t)(trb_addr & 0xFFFFFFFFu);
    depcmd_issue(ep, DEPCMD_DEPSTRTXFER, par0, par1, 0);
}

/* Pre-arm EP0 OUT with a Control-Setup TRB pointing at the setup
 * buffer. The next setup packet the host sends lands in the buffer,
 * the controller writes an XferComplete event, and the polling
 * loop picks it up. */
static void arm_setup_receive(void)
{
    fill_trb(trb_ep0_out, (uint64_t)(uintptr_t)setup_buffer, 8,
             TRB_TYPE_CONTROL_SETUP);
    depcmd_start_xfer(EP0OUT, (uint64_t)(uintptr_t)trb_ep0_out);
}

/* Configure endpoint zero (both directions) and turn the
 * controller's RUN bit on so the host's bus reset can succeed.
 *
 * Returns nonzero on a failure that prevented bring-up.
 *
 * Event-buffer DMA address must be a 4 KB-aligned physical address.
 * Page allocator pages are already page-aligned. */
int usb_endpoint_zero_bringup(void)
{
    /* Event buffer for the controller's events. */
    event_buffer_address = alloc_page();
    if (event_buffer_address == 0) {
        return -1;
    }
    mmio_write32(DWC3_GEVNTADRLO, (uint32_t)(event_buffer_address & 0xFFFFFFFFu));
    mmio_write32(DWC3_GEVNTADRHI, (uint32_t)(event_buffer_address >> 32));
    mmio_write32(DWC3_GEVNTSIZ, EVENT_BUFFER_SIZE);
    mmio_write32(DWC3_GEVNTCOUNT, 0);

    /* DEPSTARTCFG on EP0OUT initiates resource allocation for the
     * entire controller. CommandParam=0 in the high bits means
     * "start config for endpoint 0." */
    depcmd_issue(EP0OUT, DEPCMD_DEPSTARTCFG, 0, 0, 0);

    /* DEPCFG for EP0OUT and EP0IN. The parameter encoding for
     * DEPCFG packs the endpoint type, FIFO number, max packet
     * size, and burst size into PAR0; the endpoint number and
     * event mask into PAR1.
     *
     * Control endpoint (type=0), max packet 64, FIFO 0:
     *   PAR0 = (max_packet_size << 22) | (ep_type << 1) | (burst_size << 30)
     *        Conservative read: 64 << 22 = 0x10000000, ep_type=0,
     *        burst=0. So PAR0 = 0x10000000.
     *   PAR1 = (ep_number << 25) | (event_enable_xfer_complete << 8)
     *        EP number for EP0OUT=0, EP0IN=1; event mask 0x100
     *        enables XferComplete events. */
    depcmd_issue(EP0OUT, DEPCMD_DEPCFG,
                 (64u << 22),  /* PAR0: MPS=64, control type */
                 (0u << 25) | (1u << 8),  /* PAR1: ep 0, xfer-complete event */
                 0);

    depcmd_issue(EP0IN, DEPCMD_DEPCFG,
                 (64u << 22),
                 (1u << 25) | (1u << 8),  /* PAR1: ep 1, xfer-complete event */
                 0);

    /* DEPXFERCFG: allocate one transfer resource per endpoint. */
    depcmd_issue(EP0OUT, DEPCMD_DEPXFERCFG, 1, 0, 0);
    depcmd_issue(EP0IN,  DEPCMD_DEPXFERCFG, 1, 0, 0);

    /* Enable EP0OUT and EP0IN in the active-endpoint mask. */
    uint32_t dalepena = mmio_read32(DWC3_DALEPENA);
    dalepena |= (1u << EP0OUT) | (1u << EP0IN);
    mmio_write32(DWC3_DALEPENA, dalepena);

    /* Allocate TRB storage for both endpoints and the setup
     * packet buffer. Each gets its own page — wasteful but
     * gives us page alignment for free and keeps the bookkeeping
     * simple. */
    uint64_t trb_out_page = alloc_page();
    uint64_t trb_in_page  = alloc_page();
    uint64_t setup_page   = alloc_page();
    if (trb_out_page == 0 || trb_in_page == 0 || setup_page == 0) {
        return -1;
    }
    trb_ep0_out  = (struct dwc3_trb *)(uintptr_t)trb_out_page;
    trb_ep0_in   = (struct dwc3_trb *)(uintptr_t)trb_in_page;
    setup_buffer = (uint8_t *)(uintptr_t)setup_page;

    /* Turn the controller's RUN_STOP bit on. After this the host
     * can drive bus reset and start enumeration. */
    uint32_t dctl = mmio_read32(DWC3_DCTL);
    dctl |= DCTL_RUN_STOP;
    mmio_write32(DWC3_DCTL, dctl);

    /* Pre-arm EP0 OUT with a Control-Setup TRB so the controller
     * has somewhere to put the host's first setup packet. */
    arm_setup_receive();

    return 0;
}

/* ==========================================================================
 * Setup packet dispatch — turn an inbound setup packet into the
 * right response. Phase 1's response surface is small.
 * ========================================================================== */

/* Pointers used by the polling loop to remember what response is
 * queued. Real DWC3 use would post a TRB pointing at this buffer
 * and let the controller DMA it back; that TRB-posting step lives
 * inside the polling loop in the next section. */
static const uint8_t *queued_response_data;
static uint16_t       queued_response_length;
static int            queued_set_address;
static uint8_t        queued_set_address_value;

static void respond_with(const void *data, uint16_t length, uint16_t cap)
{
    queued_response_data = (const uint8_t *)data;
    queued_response_length = (length < cap) ? length : cap;
    queued_set_address = 0;
}

static void handle_get_descriptor(const struct usb_setup_packet *s)
{
    uint8_t type = setup_descriptor_type(s);
    uint8_t index = setup_descriptor_index(s);

    switch (type) {
        case USB_DT_DEVICE:
            respond_with(&device_descriptor,
                         sizeof(device_descriptor),
                         s->wLength);
            break;
        case USB_DT_CONFIGURATION:
            respond_with(&full_config,
                         sizeof(full_config),
                         s->wLength);
            break;
        case USB_DT_STRING: {
            uint8_t len = 0;
            const uint8_t *p = string_descriptor(index, &len);
            if (p != (const uint8_t *)0) {
                respond_with(p, len, s->wLength);
            }
            /* Unknown string index: leave the response queue empty,
             * the controller stalls the transfer. */
            break;
        }
        default:
            /* Unknown descriptor type — stall by leaving response
             * queue empty. */
            break;
    }
}

static void handle_set_address(const struct usb_setup_packet *s)
{
    /* The host sets the device address after enumeration. Per the
     * spec we defer applying the address until after we ACK the
     * status stage of this transfer; we mark it pending here, and
     * the polling loop writes DCFG.DevAddr once the IN status
     * stage completes. */
    queued_set_address = 1;
    queued_set_address_value = (uint8_t)(s->wValue & 0x7F);
    queued_response_data = (const uint8_t *)0;
    queued_response_length = 0;
}

static void handle_set_configuration(const struct usb_setup_packet *s)
{
    /* We have only one configuration; any nonzero value selects it.
     * No state change is needed beyond acknowledging the request. */
    (void)s;
    queued_response_data = (const uint8_t *)0;
    queued_response_length = 0;
}

void usb_handle_setup_packet(const struct usb_setup_packet *s)
{
    switch (s->bRequest) {
        case USB_REQ_GET_DESCRIPTOR:
            handle_get_descriptor(s);
            break;
        case USB_REQ_SET_ADDRESS:
            handle_set_address(s);
            break;
        case USB_REQ_SET_CONFIGURATION:
            handle_set_configuration(s);
            break;
        default:
            /* Unrecognized request — let the controller stall. */
            break;
    }
}

/* ==========================================================================
 * Polling loop — watch the event ring, dispatch each setup packet
 * through usb_handle_setup_packet, and post the response.
 *
 * For phase 1 simplicity, kernel_main calls this once per pass
 * through its main loop. After enumeration completes there is no
 * remaining work for this function until 110 adds CDC-ACM data
 * paths.
 * ========================================================================== */

/* Control-transfer state machine.
 *
 * USB control transfers move through three stages: setup (host
 * sends an 8-byte request header), an optional data stage
 * (descriptor bytes in either direction), and a status stage
 * (zero-length transfer in the opposite direction of data, or in
 * the IN direction for transfers with no data stage). We track
 * the current stage so the next event we process knows what
 * just completed.
 *
 * The stages we observe:
 *
 *   STAGE_AWAITING_SETUP  — pre-armed; the controller will write
 *                           an event when the host sends a setup
 *                           packet.
 *   STAGE_AWAITING_IN_DATA — we posted a Control-Data TRB on
 *                           EP0 IN; waiting for the host to drain
 *                           it.
 *   STAGE_AWAITING_IN_STATUS — 2-stage transfer (SET_ADDRESS,
 *                           SET_CONFIGURATION); we posted a zero-
 *                           length status TRB on EP0 IN.
 *   STAGE_AWAITING_OUT_STATUS — 3-stage transfer
 *                           (GET_DESCRIPTOR); we posted a zero-
 *                           length status TRB on EP0 OUT for the
 *                           host's status-stage ACK.
 */

typedef enum {
    STAGE_AWAITING_SETUP,
    STAGE_AWAITING_IN_DATA,
    STAGE_AWAITING_IN_STATUS,
    STAGE_AWAITING_OUT_STATUS,
} control_stage_t;

static control_stage_t current_stage = STAGE_AWAITING_SETUP;

/* Apply a pending SET_ADDRESS. The USB spec says the address change
 * takes effect after the status stage of the SET_ADDRESS transfer,
 * which is the point at which the polling loop sees the IN-status
 * XferComplete. */
static void apply_pending_set_address(void)
{
    if (!queued_set_address) {
        return;
    }
    uint32_t dcfg = mmio_read32(DWC3_DCFG);
    dcfg &= ~DCFG_DEVADDR_MASK;
    dcfg |= ((uint32_t)queued_set_address_value << DCFG_DEVADDR_SHIFT)
            & DCFG_DEVADDR_MASK;
    mmio_write32(DWC3_DCFG, dcfg);
    queued_set_address = 0;
}

/* Decide whether a setup packet implies a 3-stage transfer.
 * bmRequestType bit 7 marks device-to-host; only those carry data
 * back to the host. Host-to-device requests with wLength = 0 are
 * 2-stage (no data stage). */
static int setup_is_in_data_stage(const struct usb_setup_packet *s)
{
    return (s->bmRequestType & 0x80u) != 0 && s->wLength != 0;
}

/* Handle a setup-packet-received completion. Reads the buffer the
 * controller DMAed into, dispatches through the 109b handler, and
 * posts the next TRB based on whether the transfer is 2-stage or
 * 3-stage. */
static void on_setup_packet_received(void)
{
    const struct usb_setup_packet *setup =
        (const struct usb_setup_packet *)setup_buffer;
    usb_handle_setup_packet(setup);
    if (setup_is_in_data_stage(setup) && queued_response_length > 0) {
        /* 3-stage: post the descriptor bytes on EP0 IN. */
        fill_trb(trb_ep0_in,
                 (uint64_t)(uintptr_t)queued_response_data,
                 queued_response_length,
                 TRB_TYPE_CONTROL_DATA);
        depcmd_start_xfer(EP0IN, (uint64_t)(uintptr_t)trb_ep0_in);
        current_stage = STAGE_AWAITING_IN_DATA;
    } else {
        /* 2-stage: post the zero-length status TRB on EP0 IN. The
         * status stage of a host-to-device transfer is IN; the
         * controller uses Control-Status-2 because there was no
         * data stage. */
        fill_trb(trb_ep0_in,
                 (uint64_t)(uintptr_t)setup_buffer, 0,
                 TRB_TYPE_CONTROL_STATUS2);
        depcmd_start_xfer(EP0IN, (uint64_t)(uintptr_t)trb_ep0_in);
        current_stage = STAGE_AWAITING_IN_STATUS;
    }
}

/* Handle EP0 IN data-stage completion. Post the zero-length OUT
 * status TRB so the host can acknowledge. */
static void on_in_data_complete(void)
{
    fill_trb(trb_ep0_out,
             (uint64_t)(uintptr_t)setup_buffer, 0,
             TRB_TYPE_CONTROL_STATUS3);
    depcmd_start_xfer(EP0OUT, (uint64_t)(uintptr_t)trb_ep0_out);
    current_stage = STAGE_AWAITING_OUT_STATUS;
}

/* Handle any status-stage completion. The transfer is over; apply
 * any pending SET_ADDRESS, then re-arm EP0 OUT for the next setup
 * packet. */
static void on_status_complete(void)
{
    apply_pending_set_address();
    arm_setup_receive();
    current_stage = STAGE_AWAITING_SETUP;
}

/* Dispatch one endpoint event. */
static void handle_endpoint_event(uint32_t event)
{
    unsigned ep   = EVT_ENDPOINT_NUM(event);
    unsigned type = EVT_ENDPOINT_TYPE(event);
    if (type != EVT_EPTYPE_XFERCOMPLETE) {
        return;
    }
    switch (current_stage) {
        case STAGE_AWAITING_SETUP:
            if (ep == EP0OUT) {
                on_setup_packet_received();
            }
            break;
        case STAGE_AWAITING_IN_DATA:
            if (ep == EP0IN) {
                on_in_data_complete();
            }
            break;
        case STAGE_AWAITING_IN_STATUS:
            if (ep == EP0IN) {
                on_status_complete();
            }
            break;
        case STAGE_AWAITING_OUT_STATUS:
            if (ep == EP0OUT) {
                on_status_complete();
            }
            break;
    }
}

/* Dispatch one device event. Bus reset and connection-done both
 * mean the host is restarting enumeration; reset the state machine
 * and re-arm EP0 OUT. */
static void handle_device_event(uint32_t event)
{
    unsigned type = EVT_DEVICE_TYPE(event);
    if (type == EVT_DEVTYPE_USBRESET || type == EVT_DEVTYPE_CONNECTDONE) {
        /* The controller resets its own address to 0 on bus reset;
         * we cancel any pending SET_ADDRESS we never got to apply. */
        queued_set_address = 0;
        current_stage = STAGE_AWAITING_SETUP;
        arm_setup_receive();
    }
}

void usb_poll(void)
{
    uint32_t available = mmio_read32(DWC3_GEVNTCOUNT) & 0xFFFFu;
    if (available == 0) {
        return;
    }
    /* Walk the event buffer one 4-byte event at a time. The
     * available count tells us how many bytes the controller has
     * written since we last drained the ring. */
    uint32_t *events = (uint32_t *)(uintptr_t)event_buffer_address;
    uint32_t event_count = available / 4u;
    for (uint32_t i = 0; i < event_count; i++) {
        uint32_t event = events[i];
        if (EVT_IS_DEVICE_EVENT(event)) {
            handle_device_event(event);
        } else {
            handle_endpoint_event(event);
        }
    }
    /* Tell the controller we have consumed these bytes; it can now
     * reuse the slots for new events. */
    mmio_write32(DWC3_GEVNTCOUNT, available);
}
