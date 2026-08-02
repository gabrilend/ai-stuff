# 503 — Put it on a card

## Current behavior

**Done, and tested against pretend devices** -- `src/091`, checked by
`src/090`, 34 of 34 on 2026-08-02.

The operator names the device AND its size, and both are checked against what
the machine itself says is there -- device paths move between boots, and the
disk that was the second one yesterday may be somebody photographs today.
Naming the size too means a mistake has to be made twice, identically, to get
through.

Every objection is reported at once rather than one at a time, because an
operator about to do something irreversible should see the whole objection
instead of fixing one thing and trying again.

A read-only medium is refused and called the preferred kind, since a seed
nothing can write to can be carried from machine to machine indefinitely and
cannot be damaged by a computer dying halfway through being started. A
non-removable disk is objected to loudly and can be overridden, because a
fixed disk is sometimes genuinely the target and is usually the machine
somebody is standing at.

Written, then read back, then compared against the identity from `502`, and
the comparison is reported -- a flasher that says done without reading
anything back has told you it finished, which is a different fact from the
card being right. A mismatch names the byte it first differs at and says not
to use that card.

Many cards in one run, since one image is meant to serve many machines and
doing them one at a time is where mistakes come from.

**Tested against pretend devices only, deliberately.** A test that writes to
real disks to prove it writes to real disks is one nobody should run twice.

## Intended behavior

The image reaches a physical medium, verified, with the one operation in this
project that cannot be undone made deliberately awkward.

## Suggested implementation steps

1. Require the operator to name both the device and something identifying about
   it — its serial, its size, its label. List what was found, and refuse if the
   two disagree.
2. Make the confirmation uncomfortable on purpose. Writing an image to the wrong
   disk destroys whatever was there, and unlike every other mistake in this
   project it cannot be repaired by writing more software.
3. Write, then read back, then hash, then compare against the hash from `502`.
   Report the comparison rather than assuming it.
4. Prefer read-only media where the target supports it, and say so in the tool's
   own help. A seed nothing can write to can be carried from machine to machine
   indefinitely, plants the same thing every time, and cannot be damaged by a
   computer dying halfway through being started (`docs/003`).
5. Support writing the same image to many cards in one run, since one image is
   meant to serve many machines and doing them one at a time is where mistakes
   come from.

## Blocks

Phase 6.

## Blocked by

`502`.

## Related documents

`docs/003-datapath-the-bootstrap.md` — why the delivery medium should be
read-only.
