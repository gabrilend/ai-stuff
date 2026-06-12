# 109 — USB controller and device-mode bring-up

## Current behavior

The chip has a USB controller that is currently uninitialized or
in some default reset state. Plugging the device into a laptop
does nothing recognizable on the laptop side. We cannot ship
debug output over USB, we cannot accept firmware updates over the
cable from our running kernel, we cannot do anything USB-related.

This is the heaviest single piece of work in phase 1. USB
controllers have a large register surface, a strict state machine,
and an unforgiving wire-level protocol that the host expects us to
follow within tight timing. Bringing one up is the kind of work
that eats afternoons, evenings, and the following mornings.

## Intended behavior

The kernel brings the USB controller up in *device* mode (not
host mode — we are the peripheral, the laptop is the host). The
controller is configured with at least a control endpoint
(endpoint zero) for the enumeration handshake. The kernel
implements enough of the USB specification that, when the cable
is plugged in:

- The chip responds to the laptop's reset and setup requests.
- The chip sends the descriptors that identify it as a generic
  USB device. We pick a vendor ID, a product ID, and a product
  string ("Soren DS"). For phase 1 the device class can be
  vendor-defined (no specific class) since 110 layers CDC-ACM on
  top.
- The laptop assigns the device an address and the device
  responds to subsequent requests at that address.
- The laptop's system log shows the device successfully
  enumerated.

LED-blink codes from 106 narrate progress: "USB controller
initialized," "cable detected," "enumeration started," "address
assigned," "enumeration succeeded." When something goes wrong
inside the USB driver, the LED tells the developer at which step
it stopped.

After 109 lands, the laptop sees a USB device but it doesn't yet
do anything useful. 110 makes it do something useful (the
serial-port debug stream). Later phases layer further classes —
mass storage for in-place kernel updates, virtual ethernet for
networking — on the same controller and the same enumeration.

## Why this is harder than it looks

USB has three layers of fiddliness stacked on top of each other:

- *The controller's register interface.* Manufacturer-specific,
  often poorly documented, with subtle timing requirements (this
  bit must be set before that bit; wait this many microseconds
  before doing the next thing).
- *The USB wire protocol.* Tightly specified by the USB-IF, but
  with many small corner cases (zero-length packets, NAKs at the
  wrong moment, the host's tolerance for slow responses).
- *The enumeration sequence.* A specific dance of control
  transfers the host walks the device through. Get any step
  wrong and the host gives up and the device disappears from the
  laptop's device list.

Expect this issue to take longer than any other issue in phase 1.
Budget accordingly.

## Suggested implementation steps

1. Initialize the USB controller's clocks and power. Confirm the
   controller register block can be read and written.
2. Configure endpoint zero for control transfers.
3. Write a minimal interrupt or polling loop that handles the
   USB controller's events: reset received, setup packet
   received, transfer complete.
4. Implement the descriptors the host asks for during enumeration
   (device descriptor, configuration descriptor, string
   descriptors).
5. Implement the set-address request.
6. Test by plugging in and confirming the laptop's system log
   shows the device enumerated. On Linux: `lsusb` shows it,
   `dmesg` shows the enumeration trace.

## Related documents

- `docs/006-transport-and-networking.md` — the broader USB story
  this is the foundation of.

## Blocked by

101 (USB controller details), 104 (boot path), 106 (LED for
diagnostics during bring-up), 108 (controller buffers need
allocation).

## Blocks

110, 113, phase 7 (USB transport).
