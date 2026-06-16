# 109b — USB device enumeration

## Current behavior

After 109a, the DWC3 controller is in device mode and the
laptop's `dmesg` shows USB activity on plug-in, but the device
does not respond to the host's enumeration sequence. The host
sends the standard sequence of control transfers (get device
descriptor, set address, get configuration descriptor, get
string descriptors) and times out on every one. The laptop
eventually gives up and decides nothing useful is connected.
`lsusb` shows no entry for the device.

## Intended behavior

The kernel implements enough of the USB specification's control
endpoint protocol that enumeration succeeds. After this issue
closes:

- Endpoint zero is configured with its transfer descriptor ring
  and a buffer for the host's setup packets. The ring memory
  and the setup-packet buffer come from the page allocator
  (108).
- The kernel responds to the host's standard enumeration
  requests:
  - `GET_DESCRIPTOR(Device)` returns a device descriptor naming
    us as a generic vendor-class device with a vendor ID we pick
    (a placeholder value is fine for phase 1 — we don't need a
    real USB-IF-assigned ID until we ship), a product ID we
    pick, and a `bcdDevice` field that matches the kernel's own
    version string.
  - `GET_DESCRIPTOR(Configuration)` returns a single-configuration
    descriptor with the minimum interface descriptor count the
    USB spec requires.
  - `GET_DESCRIPTOR(String)` returns the manufacturer string
    ("Soren DS Project"), the product string ("Soren DS"), and
    a serial number string (a fixed placeholder is fine until
    issue 110 layers CDC-ACM on top, at which point a per-
    device unique serial helps the host disambiguate multiple
    plugged-in devices).
  - `SET_ADDRESS(N)` accepts the host's assigned address and
    starts responding to subsequent transfers at that address.
  - `SET_CONFIGURATION(1)` accepts the configuration selection.
- On plug-in, `lsusb` on the laptop shows the device with our
  vendor ID, product ID, and the product string. The class
  remains vendor-defined (`0xFF`); 110 adds CDC-ACM as a
  second interface descriptor on top.

LED-blink codes narrate enumeration progress: "endpoint zero
configured," "first setup packet received," "device descriptor
sent," "address assigned," "configuration selected." A failure
mid-sequence leaves the LED at the last successful stage so the
developer can decode against `docs/015-led-diagnostic-codes.md`
to find which transfer failed.

## Why descriptors live in the kernel image rather than allocated

The descriptor tables — device, configuration, string — are
read-only data the host requests during enumeration. They never
change at runtime. Storing them as `const` arrays in the
kernel's `.rodata` section is both simpler than allocating them
at boot and avoids one more thing that has to succeed before
USB works. The allocator is still used for the endpoint zero
buffer, where bytes flow in from the host and have to be
copyable.

## Suggested implementation steps

1. Write the descriptor tables as `const` C structs matching
   the USB spec's exact byte layout. Verify the layout with a
   `static_assert` on the sizeof of each descriptor type.
2. Allocate a buffer for the endpoint zero transfer descriptor
   ring and a buffer for incoming setup packets through the
   page allocator. Aligned to the DWC3 controller's required
   alignment, which the DWC3 documentation specifies.
3. Configure endpoint zero through the DWC3 controller: set
   the endpoint type, the maximum packet size (64 bytes for
   USB 2.0 high-speed), and the transfer descriptor ring base
   address.
4. Write the polling loop that watches the controller's event
   ring for setup packets, dispatches each to a small per-
   request handler, and pushes the response back through the
   IN direction of endpoint zero. Polling is fine for phase 1
   — the kernel is not doing anything else of consequence
   during enumeration.
5. Test by plugging in and confirming `lsusb` reports the
   device with the right IDs and string. If the host kernel
   logs report enumeration failures, the descriptor table
   bytes are the first thing to inspect (a wrong field length
   or endianness mismatch is the most common cause).

## Related documents

- `docs/006-transport-and-networking.md` — what later phases
  build on this.
- `docs/015-led-diagnostic-codes.md` — LED progress signals.

## Blocked by

109a, 108.

## Blocks

110, 113.

## Parent

109.
