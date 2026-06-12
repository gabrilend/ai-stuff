# 706 — USB-C virtual ethernet

## Current behavior

The USB-C controller is up in device mode (109) and CDC-ACM is
running on it (110). The USB stack supports adding more classes
on top of the same device, but the virtual ethernet class — what
makes the laptop see the device as a network adapter — has not
been added.

## Intended behavior

The kernel exposes a USB CDC-NCM (Network Control Model) class
endpoint alongside CDC-ACM on the same composite USB device.
NCM is preferred over the older CDC-ECM because it batches
multiple ethernet frames per USB transfer, which matters on the
handheld's modest USB bandwidth.

The class implementation:

- Descriptors that advertise the device as composite — one
  CDC-ACM interface for the debug serial, one CDC-NCM
  interface for the virtual ethernet adapter.
- The host's NCM driver provides an interface MAC; the device
  uses a per-device MAC for its own end. The two MACs together
  define the point-to-point ethernet link.
- Send and receive paths into the same IP stack the radio uses
  (703). Outgoing IP packets routed to a peer reachable over
  USB-C exit through this class. Incoming USB-C ethernet
  frames are parsed, IP packets extracted, and dispatched the
  same way radio packets are.

The host operating system (Linux, macOS, Windows recent
enough) recognises NCM without any driver install. The user
plugs the cable in and the device appears as a new network
adapter in the laptop's system network panel.

The combination of CDC-ACM (debug serial) and CDC-NCM
(ethernet) on one composite device is unusual but standard. The
kernel's USB device-mode plumbing (109) is the foundation; this
issue is one more class layered on top.

## Suggested implementation steps

1. Composite USB descriptors that advertise both interfaces.
2. `usb_ncm_send_frame(bytes, length)`.
3. `usb_ncm_receive_handler()` — dispatch into IP stack.
4. IP route entry that picks USB-C when the cable is plugged.

## Related documents

- `docs/006-transport-and-networking.md` — USB-C as virtual
  ethernet section.

## Blocked by

109, 703.

## Blocks

709, 711.
