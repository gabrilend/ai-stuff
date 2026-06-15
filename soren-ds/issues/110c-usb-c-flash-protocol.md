# 110c — USB-C flash protocol

## Current behavior

SoreOS lives on the eMMC's boot partition (110b). Powering the
device on with no SD card runs SoreOS. To iterate on the kernel,
the developer still has to either move a microSD between the
laptop and the device or write a new image into the eMMC from
SoreOS running off a card. Both paths require touching the
device's internals through removable storage. Neither is the
"plug in the USB cable and flash" loop the issue 101 conversation
committed to as the daily iteration goal.

The USB CDC-ACM debug channel from 110 already carries text from
the device to the laptop. There is no symmetric path for the
laptop to push a new kernel image to the device and have SoreOS
write it to the eMMC boot partition.

## Intended behavior

SoreOS's boot path checks one condition very early — within the
first few hundred milliseconds after the kernel starts. If a
**flash-mode signal** is asserted (a specific button held during
power-on, or a flag set in a small reserved area of the eMMC by
the previous boot), SoreOS enters **flash-receive mode** instead
of continuing into normal boot.

In flash-receive mode:

1. The USB controller is brought up in device mode (the same code
   path 109 produced) but with a small additional USB interface
   class exposed alongside CDC-ACM: a bulk-OUT endpoint that
   accepts arbitrary bytes from the host, and a control protocol
   for "expect N bytes," "here is the SHA-256 you'll see," and
   "commit."
2. A laptop-side tool, distributed from `src/tools/` and named
   something honest like `soren-flash`, opens the device, sends
   the new SoreOS image, reads back the device's confirmation
   that all bytes arrived intact, and issues the commit.
3. On commit, SoreOS uses the 110a block driver and the 110b
   boot.img-wrapping code to write the new image into the eMMC's
   boot partition, verifying each block as it goes.
4. On verified-good write, SoreOS clears the flash-mode flag,
   reports success through CDC-ACM, and reboots. The new image
   takes over.
5. On any verification failure, SoreOS leaves the boot partition
   alone (the in-progress write is aborted, the old image is
   either fully intact if the abort happened before the first
   write or fully replaced if the abort happened after the last
   write — never half-and-half, see below).

After this issue closes, the developer's iteration loop is:
build → connect USB-C → run `soren-flash <image>` → wait a few
seconds → the device reboots into the new image. No card
movement, no button-holding for daily iteration. Holding the
flash-mode button is the explicit, deliberate way to *enter*
flash mode; normal boots happen by default.

## Resilience to mid-flash interruption — A/B in the boot partition

A/B slots become non-negotiable as soon as USB-C flash is the
daily loop. A USB unplug, a battery hiccup, or a developer
control-C halfway through a write cannot leave the boot partition
in a state where the device will not boot. The safety doc's
scenario S1 ("power loss during flash") prescribes the same A/B
approach in the abstract; this issue makes it concrete.

The boot partition is large enough to hold two SoreOS images
side by side — call them slot A and slot B. A small reserved
area at the top of the partition holds two-bytes-plus-magic
metadata: which slot is currently active, and which slot is
about to become active (write-in-progress flag). Anbernic's
u-boot reads our wrapped image from a fixed offset; we make slot
A's start match that offset, and we control which image u-boot
sees by writing slot A or slot B's contents to that offset only
*after* the new image has been verified in the inactive slot.

If a flash is interrupted, the next boot reads the metadata,
sees the previous slot is still good, and boots that. The
in-progress write is discarded. No half-written image is ever
the active one. This costs one small atomic metadata update per
successful flash, which is well inside the eMMC's atomicity
guarantees at the block level.

## Trust posture — both ends of the wire are our code

The USB stack on the device is the 109/110 code we wrote. The
USB stack on the laptop is the kernel's standard CDC and bulk
endpoint driver, plus the `soren-flash` tool we wrote. There is
no path through Anbernic firmware, no path through chip ROM
Maskrom code, no third-party blob between the developer's build
output and the eMMC. The malware-via-USB concern from the issue
101 conversation does not apply to this loop because every byte
flowing between the laptop and the device is decided by code one
or both of us own.

The `soren-flash` tool authenticates the device with a small
challenge-response (the device sends a fresh nonce, the tool
echoes it back signed by a build-time key) to keep a rogue USB
device pretending to be the RG DS from getting our flash
commands routed at it. Likewise, the device only accepts a flash
image whose header contains the chip-ID magic the safety doc's
scenario S3 prescribes; mismatched targets refuse to write.

## Out of scope here

- *Over-the-air update.* The radio stack does not exist yet
  (phase 7) and OTA on a device with one user is anyway a
  contentious enhancement.
- *Recovery flash through the same protocol.* If SoreOS-on-eMMC
  is so broken it cannot reach flash-receive mode, the path back
  is SD card boot (which still works) into a recovery flash
  using 110b's code directly. Not this issue.
- *Authenticated, signed images at scale.* The build-time key
  scheme is enough to keep arbitrary USB devices from receiving
  our flashes; it is not a full secure-boot story. We are not
  building a secure-boot story.

## Suggested implementation steps

1. Wire the flash-mode trigger: read the chosen button's GPIO
   (chosen from the input map in `docs/014-hardware-overview.md`
   — likely a center button reserved for this) within the first
   hundred milliseconds of kernel boot. Also check the
   reserved eMMC metadata's "stay-in-flash-mode-after-reboot"
   flag (set by the previous boot, e.g. for a future "flash and
   then immediately stay in flash" workflow).
2. Implement the new USB interface alongside CDC-ACM. The bulk
   endpoints and control transfers are an incremental addition
   to the 109/110 USB descriptor table.
3. Write the on-device receive logic: accept N bytes from the
   host, hash them, compare to the host-promised SHA-256, write
   to the inactive slot using 110a, verify each block on the
   way down.
4. Write the metadata flip: atomic single-block write to the
   reserved area at the top of the boot partition that swaps
   the active slot pointer.
5. Write `soren-flash` on the laptop side in whatever language
   the project's build system (issue 103) is happiest hosting,
   linking against the kernel's CDC driver via `/dev/ttyACM*`
   for control text and the new bulk endpoint via libusb (or
   the moral equivalent) for the image payload.
6. End-to-end test: flash a known-good image, flash a known-bad
   image (header magic intentionally wrong) and confirm it is
   refused, simulate a mid-flash control-C and confirm the
   previous image still boots.

## Related documents

- `docs/014-hardware-overview.md` — the install path section
  describes exactly this loop and what falls beneath it as
  recovery.
- `notes/safety/000-bricking-and-recovery.md` — scenario S1
  (A/B slot rule) and scenario S3 (chip-ID magic) live here.
- `docs/006-transport-and-networking.md` — the USB mass-storage
  inbox/outbox in phase 7 layers further USB classes on the
  same 109/110 controller plumbing; this issue is the kernel-
  update-specific peer of that future work, not a duplicate of
  it.

## Blocked by

110a (block reads and writes), 110b (boot.img wrapping and
boot-partition write path), 110 (CDC-ACM channel for status
text), 109 (USB device-mode controller).

## Blocks

113 (phase 1 demo — the demo's iteration step uses this loop
rather than the chip ROM recovery the original phase 1 plan
named).
