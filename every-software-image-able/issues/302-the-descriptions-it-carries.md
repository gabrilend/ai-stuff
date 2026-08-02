# 302 — The descriptions it carries

## Current behavior

The machine can enumerate devices and learns nothing about how to operate them.
Descriptions can be found for essentially any modern computer, and none of them
are on the chip.

## Intended behavior

Machine-readable descriptions of the standard device classes, carried on the
image, in a format written for a computer rather than for an engineer — plus the
read-only protocol that decides whether a description is about the part in front
of it.

## Suggested implementation steps

1. Define the format. It has to hold enough to write a driver from: what
   identifies a device as a member of this class; the register map, with each
   register's offset, width and the meaning of each bit; the initialisation
   sequence including the waits, since hardware needs time between steps and
   skipping one produces failures that look random; the layout of the descriptor
   rings that data actually moves through; which conditions raise an interrupt,
   what to read to find out why, and what to write to acknowledge it; and the
   errata, which are never derivable by probing and are the commonest reason a
   correct-looking driver fails.
2. Write descriptions for the classes worth carrying: storage first, because
   `206` depends on it and the whole move-in sequence depends on that; then
   keyboard and mouse, basic display, and serial.
3. Record where each description came from. A description is a transcription of
   somebody else's document and transcriptions rot; one whose source is not named
   cannot be re-checked when a part revision lands.
4. **Implement confirmation as a read-only act.** Maker and part must match; the
   registers the description says are read-only are read and compared against
   what it predicts; reserved registers are checked against the predicted
   pattern; the revision is checked against the range the description covers.
   Confirming a description by writing to the device is the failure the whole
   exploration discipline exists to prevent.
5. Treat partial matches as failures. Enough agreement to feel confirmed with one
   silent disagreement in the register that matters is the dangerous case, not the
   safe one.
6. Provide the whole set to the model as something it can read, not as something
   compiled into the engine. A description it can read is one it can extend when
   it works out a new device.

## Blocks

`206`, `205`, and phase 6.

## Blocked by

`201`.

## Related documents

`docs/003a-datapath-careful-exploration.md` — what a description has to contain,
and the confirmation sequence.
