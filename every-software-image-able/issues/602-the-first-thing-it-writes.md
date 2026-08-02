# 602 — The first thing it writes

## Current behavior

The machine thinks. It has never made anything.

## Intended behavior

Unaided, the machine writes an allocator in assembly, runs it, finds storage,
writes itself there, and comes back after a power cycle running from the machine
rather than from the card — with what it learned still present.

**This is the capstone.** Everything before it builds a seed. This is the seed
being a seed.

## Suggested implementation steps

1. Let it write the allocator. Do not supply one, do not supply a template, and
   resist correcting the first attempt — what is being tested is whether the
   instruction in `301` and the patterns in `303` are enough, and a helped machine
   proves nothing about an unhelped one.
2. Check that the allocator protects the engine and the weights. If it does not,
   that is a failure of what the machine was told rather than of the machine, and
   the fix belongs in `301`.
3. Let it find storage and choose where to move in. Watch which storage it picks
   and why; the reasoning is more informative than the choice.
4. Let it move in, and then pull the power at a moment of your choosing. The
   window where it exists in two places or neither is the one failure this design
   cannot help with (`docs/003`), and it should be met deliberately rather than
   eventually.
5. Power on again and confirm it is running from storage and has kept what it
   learned.
6. Then leave it alone and watch it grow. What it builds, in what order, and what
   it does when it runs out of room, are the first observations anybody has of
   this kind of machine, and they belong in `notes/` rather than in a ticket.

## What would count as failure

The machine damaging hardware while exploring. Writing over its own weights. Being
unable to produce working assembly at all. Each of those points at a specific
document rather than at the idea — `003a`, `301`, and `303` respectively.

## Blocks

Nothing. This is the end of the planned work.

## Blocked by

`601`.

## Related documents

`docs/003-datapath-the-bootstrap.md` — the order it should arrive at on its own.
