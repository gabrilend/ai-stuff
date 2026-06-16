# 109c — USB control transfer plumbing

## Current behavior

`src/010-usb-enumeration.c` now carries the full transfer
plumbing the previous issue stopped short of. The dispatcher
that was correct and unreachable is now reachable.

A `dwc3_trb` struct matches the controller's 16-byte transfer-
request-block layout — 64-bit buffer pointer, 24-bit size field
plus a packet-count metadata word, and a control word that
encodes the TRB type along with the hardware-owner, last-of-
chain, and interrupt-on-completion bits. A `fill_trb` helper
populates each field in the order that keeps the hardware-owner
bit going high only after the other fields are valid.

Three pages come out of the page allocator during the endpoint-
zero bring-up: one for the endpoint-zero OUT TRB, one for the
endpoint-zero IN TRB, and one for the 8-byte setup-packet
buffer. After the controller's RUN bit is set, `arm_setup_receive`
posts a Control-Setup TRB on endpoint zero OUT and issues
DEPSTRTXFER so the controller has somewhere to land the host's
first setup packet.

The polling loop walks the event buffer four bytes at a time.
Each event distinguishes endpoint events from device events on
its low bit; endpoint events carry an endpoint number and a
type code, device events carry a different type code. The
transfer-complete event drives a four-stage state machine:
awaiting setup, awaiting IN data, awaiting IN status, awaiting
OUT status. The state machine differentiates 2-stage transfers
(SET_ADDRESS, SET_CONFIGURATION — no data stage) from 3-stage
transfers (GET_DESCRIPTOR — IN data then OUT status) by reading
the setup packet's bmRequestType direction bit and wLength.

When a setup packet arrives the polling loop reads the setup
buffer, calls the 109b dispatcher, and posts either a
Control-Data TRB on endpoint zero IN (3-stage path) or a
Control-Status-2 TRB on endpoint zero IN (2-stage path). The
next transfer-complete on the matching direction advances the
state. The SET_ADDRESS that 109b's handler queues is applied
to the DCFG register only after the IN-status XferComplete
fires, matching the USB spec's rule about when the address
takes effect.

Bus reset and connection-done events reset the state machine
to "awaiting setup" and re-arm endpoint zero OUT — the host
restarting enumeration is treated the same as boot.

The closing evidence on real hardware — `lsusb` reporting our
device with vendor `0x1209`, product `0x5050`, and the "Soren
DS" product string — has not yet been observed because we have
not booted from the device. That validation lands when 110b
puts the kernel on the eMMC. If `lsusb` reports nothing at
that point, the bug is somewhere in the TRB bit positions,
the event-decode bit-field offsets, or the DEPSTRTXFER
parameter ordering — all places where the spec is exact but
inattention to detail is easy. This issue reopens on that
evidence.

## Intended behavior

After 109c closes, the polling loop watches the event buffer,
decodes each event, and drives the transfer state machine:

1. The controller posts a "setup-packet received on EP0OUT"
   event when the host's setup packet arrives in the
   pre-armed setup buffer.
2. The polling loop parses the eight-byte setup header out of
   the buffer and calls the 109b dispatcher.
3. The dispatcher queues a response — either a pointer to a
   descriptor in `.rodata` or a pending SET_ADDRESS that
   applies after the status stage.
4. The polling loop posts a TRB on endpoint 0 IN pointing at
   the queued response bytes, issues DEPSTRTXFER on EP0 IN,
   and waits for the matching "transfer complete" event.
5. The polling loop then posts a zero-length TRB on EP0 OUT
   for the status stage, waits for its completion, and applies
   any pending SET_ADDRESS by writing the device address into
   DCFG.
6. The polling loop re-arms EP0 OUT with a fresh setup-buffer
   TRB so the controller is ready for the next setup packet.

After this issue closes, `lsusb` on the host laptop reports
the device with our vendor ID, product ID, and product string.
This is the original closing condition for the entire 109
sub-issue group.

## Suggested implementation steps

1. Define the TRB struct as a 16-byte structure matching the
   DWC3 documentation: a 64-bit buffer pointer, a 16-bit
   buffer size, a 16-bit reserved/PCM1, and a 32-bit control
   word that encodes the TRB type (Normal, Control-Setup,
   Control-Status-2, etc.), the HWO bit (hardware owns this
   TRB), and the LST bit (last TRB in a chain).
2. At boot, allocate from the page allocator: one page for the
   EP0 OUT TRB ring (256 TRBs at 16 bytes each), one page for
   the EP0 IN TRB ring, one 8-byte buffer for setup packets
   inside the event-buffer page (or its own page if alignment
   is awkward).
3. Pre-arm EP0 OUT by writing a single TRB pointing at the
   setup buffer (type = Control-Setup, HWO = 1, LST = 1) and
   issuing DEPSTRTXFER on EP0 OUT with the TRB pointer in the
   command parameters.
4. Replace the current `usb_poll` stub with an event-decoding
   loop. Read GEVNTCOUNT to find how many bytes of events are
   available; for each 4-byte event, dispatch on the event
   type. The DWC3 documentation specifies the event encoding;
   the Linux DWC3 driver source is the practical reference.
5. On a "setup-packet received" event, parse the buffer,
   call the dispatcher, post the response TRB on EP0 IN, await
   completion, post the status-stage TRB on EP0 OUT, await
   completion, apply SET_ADDRESS if pending, re-arm EP0 OUT.
6. After GEVNTCOUNT has been drained, write the consumed byte
   count back to GEVNTCOUNT so the controller knows it can
   write new events into the ring.

## Test on real hardware

Until we boot from the device, the polling loop's correctness
is unobservable. The first real test is when the kernel runs
on hardware and a USB cable is plugged in. The closing
condition is `lsusb` reporting the device; partial success
(`dmesg` shows enumeration progressing further than 109b alone
allowed but still failing at some step) is also useful
information that narrows the bug to a specific transfer step.

If the bug-hunt loop gets long, the LED stages should grow
finer: a stage per major enumeration milestone (first setup
packet seen, device descriptor sent, address assigned,
configuration set), so a developer can decode roughly how far
enumeration got from the LEDs alone before resorting to host-
side `dmesg` decoding.

## Related documents

- `docs/006-transport-and-networking.md` — what later phases
  build on this.
- `docs/015-led-diagnostic-codes.md` — LED progress signals;
  this issue may expand the table with enumeration-stage
  patterns if iteration on hardware needs them.
- `docs/016-physical-memory-map.md` — DWC3 register addresses.

## Blocked by

109b, 108.

## Blocks

110, 113.

## Parent

109.
