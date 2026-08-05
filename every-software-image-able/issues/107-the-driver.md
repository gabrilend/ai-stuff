# 107 — The driver, and what a machine cannot be told

## Current behavior

**Started, 2026-08-04. The first piece exists on all three machines.**

Step two of the ten below -- finding the model and locating every tensor --
is written and proved: `src/131`, checked by `src/132`, 14 of 14. All three
processors walk a real packed model and arrive at the same place for every
one of its tensors, and all three refuse the two failures that are otherwise
silent.

It was written first because its failure is silence in the purest form. An
address computed slightly wrong is not an error. It is a number, which the
arithmetic multiplies happily while the machine thinks about nothing -- or it
points into the engine's own instructions, and the next write there stops the
machine permanently.

**It walks by index and never reads a name.** Every entry carries a
thirty-two byte name, and matching those would mean string comparison in the
one routine that must not be clever. The packer writes tensors in the order
`034` decides, so the third tensor of the fourth layer is at an index
arithmetic can find. That is a real dependency: **if the packing order
changes, this reads the wrong tensors and says nothing** -- so the test
compares the order against the names, which is the only place names are read.

**Two refusals, with distinct numbers.** A model holding fewer tensors than
the engine expects, and a tensor claiming bytes past the end of the blob.
Both are cheap here and impossible to notice later. The numbers differ
because to somebody reading a serial port they mean different things: the
wrong model, or half of one.

---

**What remains, and what the rest of this ticket was written about.**

**Nothing runs on a bare machine after the waking code says "handing over."**
The next instruction is a halt, followed by a jump back to that halt, and
that is where a flashed machine stops today.

Every part it would hand over to exists and is proved. The arithmetic, the
conducting and the sampler are assembly on all three architectures and agree
with each other bit for bit. The tokenizer and the console are assembly on
the first architecture. What does not exist is anything that ties them
together into one program the firmware can enter.

**The thing that ties them together today runs on the development machine.**
The loop that turns text into numbers, runs the numbers through the engine,
draws a word and puts it back is written in a readable language and reaches
the assembly through a foreign-function interface. So are the assembler, the
hands, and the context. They are the readable half of the project's usual
method -- write it plainly, record what it produces, then write the assembly
and require it to reproduce those answers -- and the assembly half was
written for the arithmetic and has not been written above it.

**The image has a region for the engine and nothing fills it.** The builder
lays down five regions in order -- the waking code, the engine, the model,
the text, the carried randomness -- each starting on a block boundary. It
checks that the offsets it writes are the offsets the engine will look for,
and refuses to build if they disagree. The engine's bytes arrive as a
parameter. One caller supplies that parameter and it is a test, and it passes
two thousand copies of a single letter.

## Intended behavior

A program that the firmware enters and that never returns, whose whole job is
to keep the machine thinking.

Find the pieces. Lay out memory. Read what the machine was told. Turn it into
numbers, run the engine, draw a word, put it back, and say what came out.
Notice when what came out is a request, carry it out, and feed the answer
back in as more text. Then again, forever.

## This does not end

It was described once as running "until the machine has produced its first
program," and that was wrong. Tokenise, conduct, draw, append, say **is**
thinking on this machine. It is needed for as long as the machine is alive,
not until some milestone is passed.

What changes once the machine can build things is not that the driver
retires. It is that the machine acquires other things to do between thoughts,
and eventually the ability to rewrite the driver itself -- which it may
(`008` question 17: everything about this machine is mutable, this included).

So this is the **second place in the seed where a procedure is written down
rather than delegated**, and it is written down for the same reason the mind
is (`010`): a damaged mind cannot report that it is damaged. Not because the
machine could not decide these things for itself, but because it cannot
decide anything at all until they are decided.

## What decides whether a thing belongs in here

Not difficulty, and not "is there one right way." **What does being wrong
look like.**

If wrong looks like a wrong answer, the machine can see it and fix it. Leave
it to the machine.

If wrong looks like **silence** -- a jump into weights, a call to itself, a
return to an address that was never a return address -- the machine cannot
see it, cannot say so, and does not get a second attempt, because there is
nobody left to attempt. Write it down.

This project has met that failure four times and every one looked identical
from outside:

| What happened | What it looked like |
|---|---|
| a call whose offset stayed zero, because the assembler left a note for a linker that does not exist -- and a call with offset zero is a call to itself | the first mark printed, then silence |
| the same again on a second architecture, for a different reason (`054`) | the same silence |
| a payload entered the matrix routine with the firmware's registers as arguments, which happened to mean "no rows", so it returned -- and the firmware carried on booting to its own shell | nothing failed, and nothing was reported |
| a binary truncated at exactly 4096 bytes because an unrelated program had filled the RAM disk | half an engine, then a fault nobody had a handler for |

Sorted by that rule:

| | Wrong looks like | Whose |
|---|---|---|
| the arithmetic | a wrong number | ours, but because the order of addition **is** the specification |
| the calling convention on each architecture | a return to a wrong address | ours |
| finding the model's tensors in the image | a jump into weights | ours |
| laying out the cache and the scratch vectors | reading what was never written | ours |
| the fetch loop of anything at all | silence | ours |
| the allocator | a wrong answer, and a shortage the machine can see | the machine's |
| the storage driver | a wrong answer, or a device that stops answering | the machine's |
| what to think about next, and what to build | a bad conversation | the machine's |

## What it must do, in order

1. **Work out where it is standing.** There is no linker and no loader, so it
   cannot refer to anything by name. Every address it needs is computed from
   the address of its own first instruction. This is the single most common
   source of the silent failures above.
2. **Find the model and locate every tensor.** Read the packed model's header,
   walk its table of contents, record where each weight table begins. `102`
   already does the finding on all three architectures; what is missing is
   handing the result to the conducting.
3. **Lay out memory.** The cache of everything thought so far, the eight
   scratch vectors, the tables of addresses the conducting reads. There is no
   allocator yet and this must not need one -- the memory map from `102` says
   what is usable, and this takes what it needs from the top of it.
4. **Fill the plan.** The conducting reaches nothing by name; it asks only
   what is at a given offset of one table. Filling that table with real
   addresses is this program's job, and it is the seam where the builder and
   the engine must agree (`502`).
5. **Read what the machine was told**, out of the text region.
6. **Turn it into numbers**, through the tokenizer.
7. **Run the engine and draw a word.** The conducting, then the sampler, then
   the word joins the context.
8. **Say it**, through the console.
9. **Notice a request in what was said**, carry it out, and feed the answer
   back in. This is the hands, and it is the part that is genuinely
   unpleasant in assembly, because recognising a request is comparing byte
   strings.
10. **Go back to seven.**

Steps 1 through 4 are setup and are fiddly rather than hard. Steps 7 and 8
are small. Step 9 is the one to budget for.

## What it is not

**It is not an interpreter.** `002` is explicit that the image carries none
and that the machine writes one at first boot, against the processor it found,
so that the storage driver can be bytecode rather than more assembly. That
decision stands. But the machine cannot write an interpreter without
thinking, and cannot think without this -- so this is the piece between the
waking code and the machine's first act, and nobody had named it.

**It is not a kernel.** It takes nothing back, protects nothing from
anything, and offers no privileged door. Those three jobs belong to the
interpreter the machine writes (`002`), and they arrive when it does.

## Suggested implementation steps

1. Write it for the first architecture only, and get first light there before
   the other two exist. When it fails it will fail for reasons that have
   nothing to do with the architecture (`601`).
2. **Narrate every step.** The last thing said before silence is the entire
   diagnosis, and every failure in the table above was diagnosed by the last
   mark printed. Verbose by default; quieten later, never before.
3. Prove it under emulation first, the way everything else here was proved:
   run it on an emulated board and require the words it produces to match
   what the readable loop produces on the same model with the same carried
   randomness. The readable loop stays as the reference, exactly as the
   readable forward pass stayed the reference for the arithmetic.
4. Then hand its bytes to the builder (`502`) so the engine region holds an
   engine, and the region the builder checks against becomes a real check.
5. Expect step 9 to want its own ticket once its shape is known.

## Blocks

`601`, and therefore `602`. Nothing boots into anything until this exists.

## Blocked by

`103`, `104`, `105a` and `102` for the pieces it drives; `403` for the two
architectures whose tokenizer and console are not written.

## Related documents

`docs/002-datapath-the-interpreter.md` — what this is deliberately not, and
what the machine builds on top of it.
`docs/003-datapath-the-bootstrap.md` — the order a machine should arrive at.
`docs/010-datapath-the-mind.md` — why a procedure is written down here.
`notes/023-what-the-emulator-lies-about.md` — the four silences, priced.
