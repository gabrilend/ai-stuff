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
7. **Pull the card, at the right one of two moments.** Once the machine is running
   from memory with nothing still being read off the card, it *can* come out —
   nothing needs it. Once the machine can boot itself from disk into memory, it is
   *safe* for it to come out, because the machine can be turned off and on again.

   Between those two the machine exists only in volatile memory with nothing
   anywhere able to recreate it, and losing power there ends that machine rather
   than interrupting it. Test both milestones deliberately: confirm nothing is
   still reading the card, then power-cycle and confirm it comes back.

   After the card is out, the original of everything it was told is gone, and its
   own instruction is genuinely irreversible for the first time.

## Judge it as a rate, not as an anecdote

One machine writing a working allocator proves less than it looks, and one
machine failing proves less than it feels. The draw is deterministic per seed
(`104`), and the seed is a build parameter (`502`) — **so build twenty images
differing in nothing but their randomness, run them all, and count how many
succeed.**

That number is the actual judgement of phase 3. A single failure is a draw; a
consistent failure is an instruction that does not convey what it needs to. And
the ones that fail differently from each other say something the ones that fail
identically do not.

It also settles the argument about whether to nudge. There is no need: the next
machine is a different image, not a corrected one.

## Iterate where it is fast

This ticket's method is try, fail, change the instruction, try again with a fresh
machine — and a machine thinking hard enough to write an allocator is doing a lot
of thinking. Under emulation that runs between ten and a hundred times slower,
which would make each attempt an afternoon.

On a host of the same architecture as the guest, an emulator can hand the work to
the real processor and run at close to native speed. So the iteration loop belongs
on whichever architecture the development machines already are, with the other two
used for confirmation rather than for turning the crank.

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
