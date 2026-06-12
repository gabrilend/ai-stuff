# 707 — USB mass storage inbox/outbox

## Current behavior

Alongside CDC-ACM and CDC-NCM (706), the transport doc describes
a third USB class on the same composite device: USB Mass Storage
Class (MSC), exposing the inbox/outbox directories from the
filesystem doc. The class is not yet implemented.

## Intended behavior

A third USB interface — MSC — advertises a small block-device
backed by a RAM region under `tmp/usb-volume/`. The volume is
formatted as FAT (so Windows, macOS, and Linux all read it) and
has two top-level directories:

- `inbox/` — write-only from the laptop's view; the device
  watches for new files here and dispatches them (708).
- `outbox/` — read-only from the laptop's view; the device
  publishes files here on boot and on demand. The laptop client
  installer is the first file published.

The directories are presented to the laptop OS through the
filesystem under `/usb/inbox/` and `/usb/outbox/` (a path
prefix the runtime treats specially — every read or write under
`/usb/` resolves into the RAM-backed MSC volume instead of the
SD card).

The MSC class itself is small: SCSI commands over USB bulk
endpoints, with the kernel translating read/write block requests
into accesses against the RAM volume. The FAT layout on the
volume is fixed at boot; the kernel populates it with the
outbox's published files and an empty inbox directory.

On the laptop side, plugging in shows the device as both a
network adapter AND a removable drive. The asymmetric directory
permissions communicate intent (the user understands which
direction each folder is for without reading documentation).

The volume's contents do not persist past disconnect — the inbox
clears so half-finished imports don't replay, the outbox
reverts to its boot population.

## Suggested implementation steps

1. Composite descriptor entry for the MSC interface.
2. `usb_msc_scsi_handler()` — block read/write dispatch.
3. The RAM-backed FAT volume layout at `tmp/usb-volume/`.
4. Path mapping: `/usb/...` resolves into the RAM volume.

## Related documents

- `docs/006-transport-and-networking.md` — USB-C inbox/outbox
  section.
- `docs/011-filesystem.md`.

## Blocked by

109, 706.

## Blocks

708.
