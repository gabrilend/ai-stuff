# 702 — IBSS mode and association

## Current behavior

The WiFi controller (701) is powered on and idle. The
device-to-device chat the apps need requires IBSS (ad-hoc) mode,
not the more common station mode that talks to an access point.

## Intended behavior

The kernel configures the radio for IBSS mode and either joins
an existing Soren-DS ad-hoc network or creates one.

- The SSID is a fixed string: `soren-ds-adhoc`. All Soren DS
  handhelds use the same SSID so they form one mutual peer
  group.
- The channel is fixed at 2.412 GHz (channel 1 in the 2.4 GHz
  band). Fixing the channel sidesteps scan time at boot and
  ensures every device is reachable on the same air.
- The encryption is none. The radio packets are unauthenticated
  at the link layer; rmail (710) handles end-to-end encryption
  above the transport.

The IBSS association flow:

1. Scan briefly (a few hundred milliseconds) for an existing
   IBSS network with the fixed SSID on the fixed channel.
2. If found, join it.
3. If not found, create it. The device becomes the network's
   first member; future devices join by the same logic.

Once associated, the controller delivers received frames into
the WiFi driver's box queue. The driver's frame handler box
parses each frame's Ethernet header and dispatches by EtherType.

The unencrypted link layer means anyone with a 2.4 GHz radio in
range could in principle eavesdrop on packets. The user accepts
this tradeoff (or doesn't — they can choose to only use the
USB-C transport instead). rmail's encryption keeps the message
contents private regardless.

## Suggested implementation steps

1. `wifi_scan_for_adhoc(ssid, channel)` — short active scan.
2. `wifi_join_or_create_ibss(ssid, channel)`.
3. `wifi_frame_received_box()` — the receive-side dispatch.
4. `wifi_send_frame(bytes, length)` — the send-side primitive.

## Related documents

- `docs/006-transport-and-networking.md` — ad-hoc radio section.

## Blocked by

701.

## Blocks

703, 704.
