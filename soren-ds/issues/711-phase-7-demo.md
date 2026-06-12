# 711 — Phase 7 demo

## Current behavior

Issues 701 through 710 produce a complete networking and
transport stack. Phase 7 needs a demo that exercises every piece
end-to-end across three devices: two handhelds and one laptop.

## Intended behavior

The demo has three movements scripted in
`issues/completed/demos/phase-7/run.sh`:

### 1. Two-handheld peer discovery and exchange

Two handhelds are flashed with the kernel image and powered on
side by side. The demo:

- Waits for both to come up.
- Streams each one's CDC-ACM through a USB cable to the
  developer's laptop. The two streams run in parallel.
- Asserts that handheld A's peer table contains handheld B
  within 10 seconds of boot (discovery convergence) and vice
  versa.
- Sends an rmail message from handheld A to handheld B's
  friendly name with a known body string.
- Asserts B receives it within 5 seconds and the body matches.
- Sends a reply from B to A; asserts A receives it.

### 2. Laptop joins via USB-C

The developer plugs the laptop's USB-C cable into handheld A.

- Asserts the laptop's OS reports a new network adapter (the
  device's CDC-NCM interface from 706) and a new removable
  drive (the MSC inbox/outbox from 707).
- Asserts the laptop's IP stack pings handheld A's link-local
  address successfully.
- The laptop runs a small rmail client (provided as part of the
  demo's test harness) and sends a message to handheld B's
  friendly name. Asserts handheld B receives the message and
  the sender is reported as "laptop".
- Transport switch test: the demo briefly unplugs handheld A
  from the laptop and replugs it. The peer table on A should
  show the laptop transitioning to "stale" then back to
  "alive"; in-flight messages from B to the laptop should
  reroute through A as a relay (or pause and resume on
  reconnect, depending on rmail's behaviour).

### 3. Inbox import

The developer drops a known PNG file into the laptop's view of
handheld A's `/usb/inbox/` mount.

- Asserts the inbox watcher (708) picks it up within a few
  seconds.
- Asserts the file's bytes are handed to the paint program
  through the inter-app linkage; the paint program comes to the
  foreground of one of A's screens with the image visible.

## Suggested implementation steps

1. The script's multi-device orchestration, with one CDC-ACM
   stream per handheld.
2. The laptop-side rmail client (small Lua or C wrapper that
   speaks UDP to the device's rmail port).
3. The known PNG and its expected post-import state in the
   paint program.
4. Per-movement pass/fail assertions.

## Related documents

- `docs/002-roadmap.md` — phase 7 demo description.
- `docs/006-transport-and-networking.md`.

## Blocked by

All of 701 through 710.

## Closes

Phase 7.
