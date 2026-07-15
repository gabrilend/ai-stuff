# Transport Design — how the two ends actually talk over USB-C

USB-C is a **connector**, not a protocol. The same pins can carry USB 2.0, USB 3.x,
Thunderbolt/USB4, DisplayPort, and power delivery. So "send it over USB-C" is
underspecified — we have to pick what actually rides the wire, and that choice
shapes everything above it.

There is also a hard constraint: **two USB hosts cannot be wired together
directly.** A USB link is host↔device. So one of our two ends must act as a USB
*device* (a "gadget"); the other acts as the *host*.

## The options considered

1. **USB networking gadget → TCP.** The device end enumerates as a USB Ethernet
   adapter (Linux configfs `ncm`/`ecm` function). Both ends get an IP interface
   (`usb0`) and the transfer runs as ordinary TCP sockets. Closest to the vision's
   "TCP style," but pulls in the whole kernel networking stack and IP config.

2. **USB serial (CDC-ACM).** The device end appears as `/dev/ttyACM0`. You send a
   framed byte stream and own the ack/flow-control yourself. Simplest wire, no IP,
   good for microcontroller-class receivers.

3. **Raw bulk endpoints (FunctionFS + libusb). ← CHOSEN.** We define our own USB
   interface with two bulk endpoints (OUT and IN). The device side services those
   endpoints from userspace via FunctionFS; the host side moves bytes with libusb
   bulk transfers. Maximum control over the wire, no networking or tty semantics
   in the way, at the cost of writing the endpoint plumbing ourselves.

## Why raw bulk

- The payload is already our own framed opcode stream (see
  `docs/safe-opcode-format.md`). We do not want TCP's or a tty's framing fighting
  ours; a bulk endpoint is the closest thing USB has to "here are my bytes, move
  them," which is exactly what the `link` interface wants underneath it.
- It keeps the security story clean: the device exposes bulk data endpoints and
  nothing else — no network interface, no shell-adjacent serial console.
- It is the same shape on both ends (bulk IN / bulk OUT), so the framing + opcode
  stack above the link is literally identical on host and device.

## How each end moves bytes

**Device (Phase 3) — FunctionFS.**
- The gadget is assembled in configfs; our function is `ffs.<name>`.
- A userspace program opens the FunctionFS `ep0`, writes the USB **descriptors**
  (declaring one interface with a bulk-OUT and a bulk-IN endpoint) and the string
  table, then opens `ep1`/`ep2`.
- The main loop `read(ep_out)` for incoming frames and `write(ep_in)` for outgoing
  frames, handing each frame to/from the `link` interface.
- Requires `/sys/kernel/config` (configfs) mounted and a UDC (USB Device
  Controller) present. Confirmed **absent on the current dev machine** — this phase
  targets the gadget-capable board.

**Host (Phase 4) — libusb via LuaJIT FFI.**
- `libusb_open` the device by vendor/product id, `libusb_claim_interface`.
- `libusb_bulk_transfer` on the OUT endpoint to send frames, on the IN endpoint to
  receive them.
- libusb 1.0 is present on the dev machine (verified at scaffold time via
  `pkg-config --modversion libusb-1.0`), so the host side is developable here.

## Consequence for the rest of the codebase

Everything above the `link` interface (framing, encoder, interpreter, store) is
transport-agnostic and is built and tested in Phase 1–2 with no USB at all. The
raw-bulk decision only touches the two thin bridges in Phase 3 and Phase 4. If a
different transport is ever wanted, only those two files change.
