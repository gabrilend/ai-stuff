# 103a — Air-gapped SD card flash workflow

## Current behavior

The early phase 1 iteration loop (issues 102 through 110) requires
moving the kernel build from the main development machine — where
the source, the compiler, and the build system live — onto the
microSD card the device boots from. The main machine is the one
the developer trusts; the lab laptop is the air-gapped machine
deliberately exposed to the device, with no network connection
and nothing of value at stake (the safety design from issue 101
covers why). There is no automated path between the two machines
today, and no path between either of them and the microSD card.

Without that path, every iteration during issues 102 through 110
would be a series of manual steps the developer would inevitably
get wrong: which drive is the USB stick, which drive is the SD
card, which file is the image, did the write actually finish, did
the unmount actually flush. Manual steps in destructive paths are
how main-machine disks get accidentally `dd`-ed over. The
workflow is one of the safety-critical pieces of the project even
though it produces no kernel code itself.

## Intended behavior

Two scripts. One on the main machine pushes the build to a
dedicated USB drive. The developer carries the drive to the lab
laptop. The other script — copied onto the drive by the first —
runs on the lab laptop from the drive itself and writes the
build's kernel image onto a freshly-inserted microSD card.

The main-machine workflow:

- The developer runs the push script from the project root with no
  arguments. The script discovers the dedicated USB drive by a
  stable identifier (UUID) rather than by a `/dev/sdN` path, so
  drive-letter ordering between sessions cannot lead to writes
  hitting the wrong device. The first run reads the UUID from the
  drive already mounted by the developer at a known location and
  saves it for future runs.
- The script mounts the drive if it isn't already mounted, rsyncs
  the project's `output/` tree onto the drive, rsyncs the lab-side
  helper script onto the drive, syncs the filesystem to physical
  storage, and unmounts the drive if it had mounted the drive
  itself. (If the drive was already mounted by the developer, it
  is left mounted and the developer is told so.)
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

The USB-drive UUID is stored in the project under a known config
path so the developer never has to remember or type it. The first
run learns the UUID from wherever the developer first mounted the
drive; subsequent runs use the saved value.

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

1. Write the main-machine push script. UUID discovery (from saved
   config if present, else from the currently-mounted probe
   directory), device resolution by UUID, mount with a "did we
   mount" flag for cleanup decisions, rsync of `output/` and the
   lab-side script directory, sync, unmount (only if we mounted),
   goodbye write.
2. Write the lab-side flash script. Block-device snapshot before
   and after the SD insertion prompt, diff with explicit error on
   zero or more-than-one new device, removable-device safety
   check, typed `YES` confirmation, unmount any auto-mounted
   partitions, `dd` with `conv=fsync` and `status=progress`,
   sync, eject, goodbye write.
3. Both scripts: hard-coded project directory variable at top of
   the file with an argument override, vimfold-wrapped function
   definitions, every function documented in a single-line
   comment that explains what it does, logging to the project's
   RAM-backed `tmp/` directory.
4. Hand-test the push script against a real USB drive (the one
   the developer has mounted at `/mnt/generic`). Confirm UUID is
   saved and reused on second run.
5. Hand-test the flash script against a sacrificial USB drive on
   the lab laptop with a known small image, before exposing it to
   a real SD card.

## Related documents

- `docs/014-hardware-overview.md` — the install path this workflow
  feeds into and the trust posture that requires the air gap in
  the first place.

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
