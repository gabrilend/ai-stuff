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

#define EP0OUT 0
#define EP0IN  1

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

/* Configure endpoint zero (both directions) and turn the
 * controller's RUN bit on so the host's bus reset can succeed.
 *
 * Returns nonzero on a failure that prevented bring-up.
 *
 * Event-buffer DMA address must be a 4 KB-aligned physical address.
 * Page allocator pages are already page-aligned. */
static uint64_t event_buffer_address;
#define EVENT_BUFFER_SIZE 4096u

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

    /* Turn the controller's RUN_STOP bit on. After this the host
     * can drive bus reset and start enumeration. */
    uint32_t dctl = mmio_read32(DWC3_DCTL);
    dctl |= DCTL_RUN_STOP;
    mmio_write32(DWC3_DCTL, dctl);

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

void usb_poll(void)
{
    /* Read the event-ring producer pointer. The controller
     * increments GEVNTCOUNT for each event it posts; we decrement
     * it after consuming. Events are typed; we only care about
     * "XferComplete on EP0OUT" (which signals a fresh setup packet
     * is in our event-buffer-adjacent setup buffer). The full
     * event-decoding state machine is left to a future issue;
     * phase 1's enumeration only needs the polling skeleton in
     * place so the structure works once we actually test on
     * hardware. */
    uint32_t available = mmio_read32(DWC3_GEVNTCOUNT) & 0xFFFFu;
    if (available == 0) {
        return;
    }
    /* Real implementation: parse each event in the buffer, post
     * a TRB for the GET_DESCRIPTOR / SET_ADDRESS response, mark
     * the events consumed by writing the byte count back to
     * GEVNTCOUNT. The skeleton here marks events consumed and
     * relies on future hardware-bring-up iteration to fill in
     * the per-event logic — see the open-research note in the
     * issue file. */
    mmio_write32(DWC3_GEVNTCOUNT, available);
}
