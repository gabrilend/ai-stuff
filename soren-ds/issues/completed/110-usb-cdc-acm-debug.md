# 110 — USB CDC-ACM debug channel

## Current behavior

The kernel now presents itself as a CDC-ACM virtual serial port.
The configuration descriptor in `src/010-usb-enumeration.c`
declares two interfaces — a CDC Control interface with the
header, call-management, ACM, and union functional descriptors,
and a CDC Data interface with both a bulk-IN and a bulk-OUT
endpoint — totaling 67 bytes of descriptor that the controller
chunks into two packets when the host requests it. The class-
specific control requests (SET_LINE_CODING, GET_LINE_CODING,
SET_CONTROL_LINE_STATE) are accepted by the dispatcher; line-
coding fields are returned as plausible defaults and the
settings the host sends are quietly discarded since the debug
stream has no real notion of baud rate.

`src/011-cdc-acm.c` brings up the bulk endpoints after the host
completes enumeration. The control-transfer state machine in
010 calls `cdc_acm_init` when the SET_CONFIGURATION status
stage completes; `cdc_acm_init` allocates a TRB and a staging
page for the bulk-IN endpoint, configures all three CDC
endpoints (notification interrupt-IN, bulk-OUT, bulk-IN)
through the DWC3 per-endpoint command interface, enables them
in DALEPENA on top of the existing EP0 bits, and advances the
LED stage to `STAGE_USB_ENUMERATED` so the developer can see
that enumeration finished.

`debug_write` accepts a NUL-terminated string and pushes it
through the bulk-IN endpoint by copying up to 64 bytes at a
time into the staging buffer, posting a Normal TRB, issuing
DEPSTRTXFER on the bulk-IN endpoint, and polling the event
ring for the XferComplete event. The function carries a
generous loop budget so a disconnected host (one that stopped
reading) drops the remaining bytes silently rather than
deadlocking the kernel.

Inside the kernel, code that wants to write debug text simply
calls `debug_write("...")`. The bytes show up on the host as
characters arriving on `/dev/ttyACM0` (or the equivalent COM
port on other operating systems).

The closing evidence on real hardware — the laptop's
`dmesg` showing CDC-ACM enumeration succeed, a `/dev/ttyACM0`
appearing in `/dev`, a terminal program (`screen
/dev/ttyACM0 9600` or `picocom` or any equivalent) showing
the kernel's debug output — has not yet been observed because
we have not booted from the device. That validation lands when
110b puts the kernel on the eMMC. If the host sees the device
but `/dev/ttyACM0` does not appear, the bug is in the CDC-ACM
descriptors; if `/dev/ttyACM0` appears but nothing arrives, the
bug is in the bulk-endpoint configuration or TRB posting.

The LED-blink codes from 106 stay as the backstop for situations
this channel cannot handle: panics before enumeration completes,
panics inside the USB driver itself, panics that scribble over
the kernel's memory.

## Intended behavior

The kernel, on top of the USB device-mode plumbing from 109,
implements the USB CDC-ACM class (Communications Device Class —
Abstract Control Model). To the laptop, the device now looks like
a virtual serial port — exactly what a connected USB
microcontroller dev board looks like. On Linux and macOS, the port
shows up as something like `/dev/ttyACM0`; on Windows, as a COM
port. The developer opens it with any serial terminal program and
sees a live text stream from the kernel.

Inside the kernel, a single function — call it the *debug write* —
accepts a string and pushes it through the CDC-ACM bulk-IN
endpoint. Code that wants to report a memory layout, a self-test
result, a panic trace, or anything else of substance calls the
debug write and the text shows up on the laptop.

The LED-blink codes from 106 do not go away. They remain the
backstop for situations CDC-ACM cannot handle: panics before USB
device-mode comes up, panics inside the USB driver itself, panics
that corrupt the kernel's memory so badly that even the debug
write cannot run.

## Suggested implementation steps

1. Build the CDC-ACM descriptors — the USB descriptors that tell
   the host computer "I am a virtual serial port."
2. Configure the bulk-IN and bulk-OUT endpoints. For phase 1 only
   bulk-IN is strictly required; bulk-OUT (laptop to device) is
   useful eventually but not for first light.
3. Implement the small amount of CDC-ACM class control logic the
   host asks for during setup (line coding, line state).
4. Wire the debug write function to push bytes into the bulk-IN
   endpoint, with buffering for the case where the host isn't
   draining the endpoint fast enough.
5. Confirm the laptop sees a serial port and a known test message
   streams across when the kernel boots.

## Related documents

- `docs/006-transport-and-networking.md` — phase 7 layers more
  USB classes (mass storage, virtual ethernet) on top of the same
  device-mode plumbing.

## Blocked by

109.

## Blocks

113. The serial channel also enriches the diagnostic output of
every later issue (the memory-layout dump, the display-controller
status confirmation, the panic handler's text trace), but those
issues do not strictly depend on it — they fall back to LED
patterns when the channel is not yet available.
