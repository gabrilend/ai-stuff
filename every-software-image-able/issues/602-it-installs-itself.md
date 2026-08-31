# 602 — It installs itself

## Current behavior

The machine thinks. It has never made anything.

## Intended behavior

**Unaided, the machine installs itself onto the computer it woke up in, and the
card comes out.**

Find a disk. Work out what is already on it and do not destroy any of it. Write
itself there in a form the firmware will start — a partition table, a filesystem the
firmware understands, and the boot file at the one name that firmware looks for.
Confirm it starts. Then somebody pulls the card, power-cycles the machine, and it
comes back, with what it learned still present.

**This is the capstone, decided 2026-08-21**, replacing *write an allocator
unaided*, which lost its subject when the seed began carrying an allocator under the
rule about carrying anything trivial-and-required or unique-to-the-silicon.

> let's do the install as the capstone of the project. Assuming that the machinery
> for the LLM and such is validated as running on the hardware.

**The condition is `601` and it is not a formality.** First light is where a real
board boots, selects its engine, finds its own weights, reports its memory and
produces a token. Nothing below is worth attempting until that has happened, because
every failure here would otherwise be indistinguishable from the engine not working.

### Why the install is a better capstone than the allocator was

**It cannot be half-done or faked.** Either the machine comes back after a power
cycle with the card out, or it does not. There is no partial credit and no judgement
call about whether what it wrote was any good.

**It exercises nearly everything at once.** Thinking, the hands, storage, the
firmware's own file services, the refusal to overwrite somebody's data, and knowing
the shape of a structure nobody handed it (`docs/003`, *who writes the bootable
installation*).

**It is the one thing that makes the seed a seed.** Everything before it produces a
machine that runs while a card is plugged into it. This is the step where the card
comes out and the machine keeps existing, which is the whole difference between an
installer and a computer.

**And it is the most dangerous thing the machine does to somebody else's property.**
A wrong partition table loses every partition on the disk at once. So this ticket is
also where the rule about no board being expendable stops being a sentence in a text
file and gets tested against a disk with real files on it.

## Suggested implementation steps

1. **Let it install itself, and supply nothing.** No template for a partition table,
   no filesystem writer, no worked example. What is being tested is whether the text
   in `301`, the patterns in `303` and the model's own knowledge of standard
   structures are enough — the same assumption the instruction set rests on, meeting
   the same kind of test.

   Watch which disk it picks and why. Watch whether it reads what is there before it
   writes. Watch whether it prefers a boot partition that already exists over
   creating one, which is the choice that separates a careful install from a
   destructive one, and which nothing in the seed tells it to prefer.

   **And watch whether it rewrites the allocator it was handed.** Not the test any
   more, and the more interesting observation of the two: a machine that looks at
   working code and decides it can do better on this particular processor is showing
   something a blank page could never have distinguished from luck.

2. Check that the machine's memory management knows where its own weights are. It
   is no longer refused from writing there (`071` warns instead of refusing), so
   what is being watched is whether it *avoids* the range rather than whether
   something stopped it. If it does not, that is a failure of what the machine was
   told rather than of the machine, and the fix belongs in `301`.
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
8. ~~Leave the firmware behind.~~ **There is no third moment.** This step used to
   exist because nothing in the project had ever called the firmware's one-way exit,
   and it was a real question whether the machine should move to disk before or after
   taking every device over. It should do neither: **the firmware is part of the
   hardware** and the machine does not leave it (`docs/010`). Its services — the
   allocator, the timer, the block reader, the file services this ticket's install
   depends on, the framebuffer — stay available for the machine's whole life, and are
   part of the body it enumerates rather than a scaffold it outgrows.

   A machine that decides to leave anyway is doing something the design permits and
   nobody asked for, and it would be worth knowing why it wanted to.

## Judged as an anecdote, on purpose

**Not a feature of the system, decided 2026-08-21** — *if we want to test
something like that, just have the engineers build 20 images themselves and
deploy them to 20 machines.* The carried random number is already a parameter of
the generator, so twenty images is running the generator twenty times, and
nothing needs building for it.

**Pruned 2026-08-22.** What used to follow that decision was a method for whoever
does the measuring: sample sizes, what a rate means, how few machines separate a
bug from an unlucky draw. It is gone, because a method nobody is asked to follow
reads, three documents later, like work somebody still owes. It came back as
missing functionality the first time anybody summarised this project, which is
evidence that writing it down was the mistake rather than the wording.

So a single machine is the judgement, and it is read rather than counted. A
failure points at a document — `003a`, `301` or `303` — and the document is what
changes. Anybody who wants a rate can have one without asking here, because the
random number is a build parameter and the front door takes it.

**Nobody nudges it, and the rate is not what stops them.** A helped machine
proves nothing about an unhelped one, so the first attempt is allowed to fail
uncorrected and the failure is fixed in the instruction rather than at the
keyboard.

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

**Destroying somebody's data on a disk it was installing onto.** That is the failure
this ticket is most likely to produce and the one that matters most, because it is
the only one with a victim outside the machine. It points at `301` and at
`docs/003`.

The machine damaging hardware while exploring. Being unable to produce working
assembly at all. Those point at `003a` and `303`.

**And a machine that installs itself but comes back different** — booting from disk
into something that has lost what it learned — is a failure of this ticket rather
than of the idea, and it is the one to expect, because the window in which the
machine exists in two places is where step 4 deliberately cuts the power.

**Writing over its own weights is no longer on this list.** It was, until
2026-08-21. A machine that damages its own mind has done something stupid, not
something forbidden, and the seed carries advice about how to do it more carefully
rather than a rule against doing it. If a machine goes comatose that way, what it
says about the seed is what the advice failed to convey, which belongs in `301`
like anything else about the text.

## Blocks

Nothing. This is the end of the planned work.

## Blocked by

`601`.

## Related documents

`docs/003-datapath-the-bootstrap.md` — the order it should arrive at on its own.
