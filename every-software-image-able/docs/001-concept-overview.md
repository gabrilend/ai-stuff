# 001 — Concept Overview

What this is, what it promises, and what it refuses to promise.

## The one-page version

An image is flashed onto a computer. On that image: a language model, and an
instruction to build every piece of software it can fit onto the drive.

There is no operating system on the image. There is no compiler on the image.
The machine wakes with no floor under it, finds out what body it has, and writes
the floor itself — memory management first, in assembly, against hardware that
nobody surveyed in advance.

After that it does one thing for the rest of its life: something asks for a
capability it does not have, and it acquires one.

## The floor, and why it is not where you would expect

The seed page says the given floor of capability is "usually a compiler, as it's
considered an interface between the hardware and software layers." The floor is
lower than that here. What is given is **the chain from text to source to a
runnable program**, and both of those arrows are allowed to improve rather than
being fixed machinery.

That has a consequence which shapes everything downstream. On an ordinary
computer a kernel provides three things, and this machine has none of them at
boot:

| What a kernel provides | The mechanism | What replaces it here |
|---|---|---|
| Taking control back from a running program | A chip pulses a line into the processor thousands of times a second; the processor stops mid-instruction and jumps to an address held in a table | A countdown maintained by the interpreter that runs the program (`006`) |
| Keeping one program out of another's memory | Every address a program uses is rewritten through a lookup table before it reaches the memory chips | A bounds comparison performed where the address is resolved (`002`) |
| One agreed door between a program and the machine | A numbered list of a few hundred requests, reached by a special instruction that flips the processor into a privileged mode | A numbered list of operations the interpreter understands (`002`) |

All three move into the translation. **The compiler is the kernel.** There is no
privileged mode because nothing needs to trap: the thing that would have enforced
the rule is the same thing that writes the program.

None of those three are missing from the design. They are missing from the
*image*. An interrupt handler and an allocator and a door are all items on the
list of software the machine is supposed to build, so the floor rises from
underneath as the machine notices it keeps losing work.

## What "every piece of software imaginable" can mean on one drive

The obvious objection is arithmetic: the set of imaginable programs is unbounded
and a drive is not.

The answer is that the machine does not store programs. It stores the smallest
set of parts that combine into them, and it squeezes duplication out
continuously. When two pieces of software know how to do the same thing, they
become one piece that knows how to do it once, and what leaves the drive is the
duplication rather than a capability. Deleting costs verbosity, not utility.

So the machine grows denser rather than fuller. The same drive reaches more
software in its second year than its first, without having gained a byte.

## The contract

**What this machine promises.**

- To find out what hardware it is attached to, as clearly and coherently as it
  can, and to say so.
- To accept requests from every channel its body provides.
- To attempt any request through four escalating rungs (`005`), and to say which
  rung it reached.
- To explain every choice it makes with a picture that shows what it chose
  against, not only what it chose (`004`).
- To damage no hardware while exploring it, and to treat that as a constraint
  rather than a preference (`003`).

**What it does not promise.**

- That two of these machines are alike. They diverge from the image in the first
  minute and never converge back.
- That it is verifiable by hashing. What it is running is not what it was
  flashed with, and cannot be. Any claim about what a given machine is has to
  come from what it wrote down along the way, not from comparing it to a
  reference.
- That it will not run out of room. It will. Running out of room is a normal
  event that triggers condensation, not an error.

## The shape of the whole thing

```
flashed image: a model, and an instruction
   → find memory                    write an allocator, in assembly       003
   → find the body                  enumerate what is attached            003
   → learn to operate the body      one datasheet per class, carefully    003
   → open a channel on each part    now the machine can be asked things
   →
   ↻ a request arrives from anywhere
        can what is here already do it?              rung 1               005
        can something here be altered to do it?      rung 2               005
        make room, and build it                      rung 3               005
        condense, so the room came from duplication  rung 4               005
     every step of that emits a status, in colour and shape               006
     when a status saturates, the machine stops and works backward        006
```

## Reading order

`001` → `005` → `003` → `004` for the design. `002` and `006` are the two
mechanisms everything else stands on and can be read in either order. `008` is
the list of things nobody has decided yet, and it is the most useful document
here for anyone about to write code.

## Open questions

Held in `008-open-questions.md`, all of them, so that none of them are buried at
the end of a document nobody opens. Four are answered and four are blocking.
