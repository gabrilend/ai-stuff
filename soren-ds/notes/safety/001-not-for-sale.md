# Not for sale: Soren DS is designed, not deployed

**Soren DS will not be sold, shipped or installed on any consumer
device until every layer of code beneath it is code we can read,
build and replace.  Today that is not true on any device we have,
so today it is a design and a prototype only.**

Decided by the owner on 2026-10-13: "we may never deploy this to any
consumer device, for we cannot guarantee that it is unhackable. We
know about its vulnerabilities, so we will not sell it. We will still
design the thing, so that when we are able to deploy it, we can."

## Why

The design principle of Soren DS is that it is unhackable by any of
the owner's peers.  A kernel cannot keep that promise about code that
runs beneath it.  On the prototype, the Anbernic RG DS (Rockchip
RK3568), these run before or below the Soren kernel
(`000-bricking-and-recovery.md` lists the boot layers):

| Layer | What it does | Source | Still running once Soren runs? |
|---|---|---|---|
| Maskrom | the chip's first loader, burned into the silicon | closed, Rockchip | no, but it decides what runs next |
| RKDDRBin | sets up the RAM controller | closed, shipped as a compiled file | no |
| miniloader | loads the next stage | closed, Rockchip | no |
| BL31 (secure firmware, "ATF") | power control and CPU start-up, at the chip's highest privilege level (EL3) | closed in Rockchip's build; an open version (Trusted Firmware-A) exists | **yes**: it stays resident in the first 2 MB of RAM (`docs/016-physical-memory-map.md`), above the Soren kernel's privilege level (EL1) |
| u-boot | loads the Soren kernel image | open | no |

The Soren kernel can neither read the secure firmware's memory nor
watch what it does.  Code there could watch or change anything the
kernel does, and the kernel would not know.  This is the same
problem rmail states plainly in its README ("if your operating system
is compromised, there is nothing we can do"), one level further down.

How this was missed: the boot layers were first studied to answer
"how do we avoid bricking the device?"  From that side, closed layers
we cannot damage are a safety net.  The other question — whose code
runs below ours? — was first asked on 2026-10-12, in the r-mail
project's conversation.

## What this means for the work

- **Keep designing and building.**  The design should be ready to
  deploy on the day a device allows it.
- **Run Soren only on the owner's own prototypes**, as a design that
  is still being built.  It is not presented to anyone as secure.
- **Nothing is sold, shipped, or installed on someone else's device.**
- **Choosing hardware**, now and for the next device, includes asking
  how much of its boot chain is open.  Two routes to a deployable
  device:
  1. *Shrink the closed part on this chip*: build u-boot's own first
     stage (replacing the miniloader) and the open Trusted Firmware-A
     (replacing Rockchip's secure firmware) ourselves.  The closed part
     left would be Maskrom and the RAM setup file.  Not enough by
     itself, but much smaller.
  2. *Choose a chip whose RAM setup is open code*, so that only the
     chip's own ROM is closed.  Candidates have to be checked against
     current boards when the time comes; none is named here, because a
     name written now would go stale.

## Where this is stated

This file is the full statement.  A short notice pointing here sits
at the top of `notes/vision/000-vision.md`,
`docs/000-table-of-contents.md`, `docs/001-architecture-overview.md`,
`docs/014-hardware-overview.md`, `docs/016-physical-memory-map.md`
and `notes/safety/000-bricking-and-recovery.md`.  If this decision
ever changes, change all of them together.
