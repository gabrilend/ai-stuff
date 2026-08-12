# 103a — Air-gapped SD card flash workflow

## Current behavior

There are now two routes from a built image to a written microSD
card, and they share their last step.

The original route — the one this issue was opened for — carries
the image across a physical air gap on a dedicated USB drive. It
is described in full below and has been exercised end-to-end
against real hardware.

The second route, `scripts/lab-side/build-and-flash`, replaces the
drive with a network copy and is described under "The networked
route" further down. It is written and its transfer logic has been
exercised against the real 285 MiB image with a stubbed ssh, but it
has **not yet been run against the real lab laptop, a real ssh
connection, or a real SD card**. Until that happens the air-gapped
route remains the one to trust for anything that matters.

`scripts/push-to-usb` runs on the main
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

## The networked route

`scripts/lab-side/build-and-flash` collapses the whole round trip
into one command typed on the lab laptop. It opens a single ssh
connection to the dev machine and reuses it for every step; runs
the compile step and the image-assembly step over there; reads the
size and SHA-256 of the image at the source; copies the lab-side
helper scripts to this laptop so it stays current; rsyncs the image
across; re-hashes it locally and refuses to continue on a mismatch;
and then hands off to `flash-sd`, which is unchanged and still owns
every rule about what is safe to write to.

The dev machine is a required argument rather than a hard-coded
value. Unlike the USB drive's UUID — which belongs to a piece of
hardware this project owns and which changes only when the drive is
reformatted — the route from the lab laptop to the dev machine is a
property of whatever network they are both sitting on that day. A
baked-in hostname would be stale the first time either machine
moved, and a stale hostname in a script that builds and flashes is
worse than no hostname at all.

The image stages in RAM at `/dev/shm/soren-ds`, following the
project's two-tier convention: artifacts on the shared-memory tier,
executable code on the `/tmp` tier (some hardened installs mount
`/dev/shm` `noexec`, and a helper script staged there would refuse
to run). Two consequences follow. A stale image cannot survive a
reboot and be written to a card by mistake. And the transfer must
be cheap enough to repeat after every reboot — which it is, because
the image is mostly zeroes: rsync's compression shrinks it on the
wire, and `--sparse` writes the zero runs as holes, so the 272 MiB
image occupies under 2 MiB of actual RAM.

Only `bootable-sd.img` crosses the network, never the whole output
directory. The USB route could afford `rsync --delete` across all of
`output/` because the drive is large and the copy is local to the
machine; over a network the same rsync would drag a multi-gigabyte
ROCKNIX reference image along with it for no purpose.

Hashing at both ends is new to this route rather than inherited
from the USB one. The physical drive's failure modes are visible —
you know whether you unplugged it early. A network transfer into a
tmpfs has quieter ones, and the check costs about a second against
a transfer measured in tens of seconds.

The script keeps its sibling lab-side tools up to date on every run,
including its own copy. Replacing a script while bash is reading it
would be a genuine hazard; it is safe here only because rsync writes
a temporary file and renames it over the target, so the running
shell keeps reading its original inode through an open descriptor.
This is why the helper sync must never gain `--inplace`. A run that
replaces its own copy says so and keeps going with the old logic,
because that is the logic the developer actually invoked.

## The return trip, and why it stays two commands

`build-and-flash` only goes one direction. Reading a log back off
the card stays what it already was — `dump-from-sd` writes
timestamped files into `lab-output/` under the staging root, and a
plain `rsync` sends them to the dev machine. Deliberately not
wrapped in a script: the dump step is occasional rather than
per-iteration, it is already one command, and a wrapper would have
to guess which of several dump shapes the developer wanted.

The one part that is not obvious is that the destination has to be
made first:

    dump-from-sd <staging root>
    ssh <dev machine> mkdir -p /tmp/soren-ds/logs
    rsync -av <staging root>/lab-output/ <dev machine>:/tmp/soren-ds/logs/

`rsync` creates only the *last* missing level of a destination
path. After the dev machine reboots, `/tmp/soren-ds` and `logs/`
under it are both gone — two levels — and the transfer fails with
`mkdir "…/logs" failed: No such file or directory` before sending
anything. This is the same reboot-clears-`/tmp` problem the build
system handles for its own work directory (see 103); it applies to
the far end of the return trip for exactly the same reason, and
the fix is the same one-line `mkdir -p` in front of the use.

## What the networked route costs

This route connects two machines that the air-gapped route
deliberately kept apart. The paragraph under "Why two scripts rather
than one" describes that separation as a property of the project;
with this script present it is a property of *which route the
developer picks*, and that is worth stating plainly rather than
leaving the older paragraph to imply otherwise.

What the air gap bought was that a compromise of the lab laptop
could not reach the dev machine, and vice versa. The networked route
spends exactly that. It is the right trade when the cost being paid
is a walk across the room on every one-line kernel change, and the
wrong trade when the lab laptop has been anywhere untrusted. Both
scripts stay in the tree so the choice stays available; neither
deletes the other.

Note also that the connection is opened *from* the lab laptop, so
the dev machine is the one running sshd and the laptop is the one
holding a key to it. That is the direction that puts the credential
on the machine that is easier to re-image.

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
