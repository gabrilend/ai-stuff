# 110 — USB CDC-ACM debug channel

## Current behavior

After 109, the chip's USB controller is up in device mode and the
laptop sees the device as a recognizable but useless USB device.
The kernel can blink the two LEDs (per 106) for boot-stage codes,
but it cannot send detailed text — a memory-layout dump, a panic
trace, a self-test report — to the laptop. Detailed debugging is
still impossible.

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
