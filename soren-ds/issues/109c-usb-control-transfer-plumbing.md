# 109c — USB control transfer plumbing

## Current behavior

After 109b the device's USB controller is configured, endpoint
zero is brought up, and the descriptor tables exist. But the
host's enumeration still hangs: the host sends a setup packet,
the controller writes that setup packet to a buffer somewhere
in its event ring, our polling loop reads the event count, and
the events are immediately marked consumed without being
parsed. The dispatcher in 109b is correct and unreachable.

Specifically, three pieces of infrastructure are missing:

- **TRB rings per endpoint.** A TRB (Transfer Request Block) is
  a 16-byte controller-readable descriptor saying "transfer
  these bytes." Endpoint 0 OUT needs a ring of TRBs the
  controller consumes to receive setup packets and status
  stages; endpoint 0 IN needs a ring the controller consumes
  to deliver response data. We have no TRB struct defined and
  no rings allocated.

- **Setup-packet buffer.** Pre-arming the controller to receive
  the host's first setup packet means posting a TRB on
  endpoint 0 OUT that points at an 8-byte buffer. The
  controller DMAs the host's setup packet into that buffer.
  Without this, setup packets land somewhere we never read.

- **Event-ring decoder.** Each entry in the event buffer is a
  4-byte event with a type field. Some events are device-wide
  ("bus reset," "connection done"); some are per-endpoint
  ("transfer complete," "setup-packet received"). The polling
  loop currently does not distinguish events at all — it just
  marks every byte consumed without reading them.

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
