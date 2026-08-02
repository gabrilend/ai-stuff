# 503 — Put it on a card

## Current behavior

An image exists as a file. Nothing writes it to hardware.

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
