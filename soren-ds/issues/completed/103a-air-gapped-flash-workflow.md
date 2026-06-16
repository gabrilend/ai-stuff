# 103a — Air-gapped SD card flash workflow

## Current behavior

The workflow is in place. `scripts/push-to-usb` runs on the main
machine, identifies the dedicated USB drive by a hard-coded UUID,
confirms sudo before any destructive step, mounts the drive at
the project's own `/mnt/soren-ds`, rsyncs `output/` and the
lab-side helper, syncs physical storage, unmounts, and removes
its mount point. Output is a couple of headline lines followed
by two progress lines (`mounting... syncing... done` and
`cleaning up... done`, with `done` in green and any error shown
as red `error` followed by the underlying message on the next
line). A trap guarantees the mount is released even if any step
crashes. The push side has been exercised end-to-end against a
real drive and behaves as designed.

`scripts/lab-side/flash-sd` runs on the lab laptop from the USB
drive itself. It identifies the SD card by a before/after diff
of the kernel's block-device list, requires a typed `YES`
confirmation, refuses targets that are neither marked
removable by the kernel nor on the MMC transport, dd's the
image, syncs, and ejects.

The "marked removable OR on the MMC transport" rule is a
widening of the original "marked removable" rule, surfaced
on the first real run of the script. The kernel's removable
flag describes the *slot*, not the medium: USB-attached SD
card readers report removable=1 because the whole reader is
hot-pluggable, but laptops with a built-in SD slot report
removable=0 because the slot itself is fixed even though the
card in it is removable. The MMC-transport check picks up
the built-in-slot case without also accepting the laptop's
internal SSD (which is on SATA or NVMe transport, not MMC).

The lab laptop's role has narrowed since issue 101 closed: it
will only ever write microSD cards, never connect to the device
over USB-C. The threat-model hardening originally planned for
the laptop (USBGuard, deny-by-default USB policies) was scoped
against a device-to-laptop USB-C connection that no longer
happens in this workflow, and is dropped.

## Intended behavior

Two scripts. One on the main machine pushes the build to a
dedicated USB drive. The developer carries the drive to the lab
laptop. The other script — copied onto the drive by the first —
runs on the lab laptop from the drive itself and writes the
build's kernel image onto a freshly-inserted microSD card.

The main-machine workflow:

- The developer runs the push script from the project root with no
  arguments. The script identifies the dedicated USB drive by a
  hard-coded filesystem UUID at the top of the script, rather than
  by a `/dev/sdN` path. The UUID is the only piece of project
  state the script carries; reformatting the drive is the rare
  case where the developer edits one line at the top of the file
  to point at the new UUID. A comment beside the variable lists
  the commands that print the value.
- The script confirms sudo at the start, before any destructive
  step. Cancelling at the password prompt leaves the drive
  untouched.
- The script refuses to proceed if anything else is already
  mounted at the project's dedicated mount point (`/mnt/soren-ds`).
  If the drive is currently auto-mounted somewhere else, the
  script unmounts it from there before remounting it at the
  project path. After the rsync of `output/` and the lab-side
  script directory, the script flushes physical storage, unmounts
  the drive, and removes its own mount point so it does not
  accumulate between runs.
- The developer unplugs the drive and physically carries it to the
  lab laptop.

The lab-laptop workflow:

- The developer plugs the drive into the lab laptop, mounts it,
  changes into the drive's mount point, and runs the lab-side
  flash script from there.
- The script snapshots which block devices are currently visible
  to the laptop's kernel, prompts the developer to insert the
  microSD card (via a USB reader or built-in slot), snapshots
  again, and diffs to identify the new block device — which is the
  SD card. If zero or more than one new device appears, the script
  refuses to proceed and reports the ambiguity. If the developer
  already knew which device to flash, an override argument bypasses
  the snapshot step.
- The script verifies the target is a removable device (refusing
  to flash an internal disk under any circumstance), shows the
  developer the source image and the destination device with its
  size, and requires a typed `YES` confirmation before continuing.
- The script unmounts any partitions the kernel auto-mounted on
  the SD card, writes the SoreOS image with `dd`, syncs, and
  ejects the device cleanly. The developer pulls the card and
  plugs it into the RG DS.

Both scripts log to the project's `tmp/` directory (which the
project rules say is RAM-backed and ephemeral). Both scripts
write a small goodbye line to the project's `output/` directory on
exit, as the conventional last-thing-a-program-does signal.

## Why this is its own issue rather than part of 103

Issue 103 is the build system — the rules and machinery that turn
source into the kernel image. This issue is post-build dev
infrastructure that transports that image across an air gap and
onto removable storage. The build system can change without this
workflow needing to change; this workflow can change without the
build system needing to change. They share an interface — `output/`
contains exactly one `.img` file when a build has produced one —
and nothing else. Keeping them separate keeps each one's surface
small.

## Why two scripts rather than one

The main machine and the lab laptop are deliberately not connected
to each other or to the network. A single script that knew about
both machines would either be unmounted from one of them or
require manual copying of itself, which defeats the point. By
having the push script ship the flash script onto the drive, the
drive carries everything the lab laptop needs and the lab laptop
never had to be set up with project-specific tooling.

The flash script is fully self-contained and depends only on
standard utilities (`lsblk`, `dd`, `sync`, `mount`, `umount`,
`eject`, `findmnt`) that ship with every Linux distribution
including the Gentoo install on the lab laptop. No project-
specific dependencies travel through the air gap, and the script
remains readable to anyone inspecting the drive.

## Drive identification — by UUID, never by device path

`/dev/sd*` device names are dynamic. Plug a different USB device
in first today and the same drive that was `/dev/sdd1` yesterday
is `/dev/sde1` today. Writing to the wrong path overwrites
whatever happens to be at that path now. Both scripts identify
storage by stable identifier (`/dev/disk/by-uuid/$UUID`) and
refuse to operate on a path that the developer might have meant
for a different device.

The USB-drive UUID is hard-coded at the top of the push script
as a single variable with a comment describing how to refresh it
if the drive is ever reformatted. We chose the hard-code over
runtime configuration discovery because the drive is dedicated to
this workflow and its UUID changes only when the developer
reformats it — a manual, deliberate event that is the right
moment to also edit one line of the script. Drive identification
remains stable across plug-orderings; the developer never has to
remember the UUID; and the script carries no opaque state files
that future readers have to chase down to understand what
storage it operates on.

The SD card has no pre-known UUID — fresh cards aren't formatted
yet and labels haven't been written. The flash script identifies
it by the before-and-after snapshot of the kernel's block device
list, with the developer's confirmation as the final safety gate.

## What is deliberately not handled

- *Verifying the written image after dd.* A read-back-and-compare
  pass would catch SD cards going bad during a write, but it
  doubles the wall-clock time of every iteration. Issue 110b's
  own integrity check protects the eMMC write (the higher-stakes
  one); the SD write is treated as cheap to repeat.
- *A/B image management on the SD card.* The SD card is the
  fallback boot path while the eMMC takeover work hasn't landed.
  Either it boots SoreOS or it doesn't; if it doesn't, the
  developer writes a known-good image to it. No slot scheme is
  needed here.
- *Encryption at rest on the USB drive.* The drive crosses a
  physical gap between machines under the developer's control; an
  attacker with hands on the drive has already won, and the
  contents are publicly-derivable project artifacts anyway. No
  threat the project defends against is mitigated by encrypting
  the drive.

## Suggested implementation steps

1. Write the main-machine push script. Hard-coded drive UUID at
   the top with a comment naming the commands that print it,
   sudo confirmed at the start before any destructive step,
   refuses to clobber the project mount point (`/mnt/soren-ds`)
   if anything else is mounted there, unmounts any auto-mounted
   path the drive might be at before remounting at the project
   path, rsync of `output/` and the lab-side script directory,
   sync, unmount, removal of the mount point, goodbye write.
2. Write the lab-side flash script. Sudo confirmed at the start
   before any destructive step, block-device snapshot before and
   after the SD insertion prompt, diff with explicit error on
   zero or more-than-one new device, removable-device safety
   check, typed `YES` confirmation, unmount any auto-mounted
   partitions, `dd` with `conv=fsync` and `status=progress`,
   sync, eject, goodbye write.
3. Both scripts: hard-coded project directory variable at top of
   the file with an argument override, vimfold-wrapped function
   definitions, every function documented in a single-line
   comment that explains what it does, logging to the project's
   RAM-backed `tmp/` directory, single final line of "what to do
   next" output rather than multi-line instructions.
4. Hand-test the push script against the real USB drive.
5. Hand-test the flash script against a sacrificial USB drive on
   the lab laptop with a known small image, before exposing it to
   a real SD card.

## Related documents

- `docs/014-hardware-overview.md` — the install path this workflow
  feeds into and the trust posture that requires the air gap in
  the first place.
- `docs/011-filesystem.md` — the FAT32-everywhere discipline that
  applies to the air-gap drive for the same reason it applies to
  the SD card.

## Blocked by

Nothing structurally. The scripts can be written before any
kernel image exists; they handle empty `output/` gracefully.

## Blocks

102 through 110 only loosely. Those issues can produce build
artifacts without this workflow, but iterating on them requires
this workflow (or a manually-substituted equivalent that the
developer would have to remember the steps of). Phase 1 demo
(113) hard-blocks on this — the demo's iteration step is
exactly the workflow this issue produces.
