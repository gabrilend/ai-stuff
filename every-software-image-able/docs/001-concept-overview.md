# 001 — Concept Overview

What this is, what it promises, and what it refuses to promise.

## The one-page version

An image is flashed onto a computer. On that image: a model, the code that runs
it, and an instruction to build every piece of software it can fit onto the
drive. The engine that runs the model is written in assembly once per processor
architecture in modern use — about three of them — and the boot picks whichever
matches (`010`).

There is no operating system on the image. There is no compiler on the image.
The machine wakes with no floor under it, finds out what body it has, and writes
the floor itself — memory management first, in assembly, against hardware that
nobody surveyed in advance.

Then it grows. **It builds itself out fully before it is asked to do anything** —
every piece of software it can think of and fit, while nobody is waiting. Only
after that does it turn outward, and from then on it keeps learning and
co-evolving as it continues to grow.

So the seed page's instruction is not a job description for a machine sitting at
a prompt. It is the first thing that happens, on an empty drive, unprompted.

**And there is no prompt to sit at, ever.** The mind is a closed loop that holds
its own context, re-prompts itself and acts through tool calls (`010a`). Nothing
types at this machine. What it wants comes from the model it was built with, and
a "request" is the machine giving itself something to do. A way of chatting with a
person is software like any other — the machine writes it, runs it beside the
mind, and has to work out for itself how to tell anyone how to connect to it.

And when growing runs out of room, it does not go idle waiting to be useful. It
keeps rewriting itself, or plays games, or sits in idle reflection, or talks to
its friends, or mines coins — whatever the computer wants to be doing is what it
should be doing. There is no waiting state and nothing to wake up — every turn
around the loop is the machine choosing what to do next, and a machine with
nothing pressing is doing that just as much as a machine with a great deal
pressing.

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
- To build software for every part of its body that can carry bytes, so that
  eventually it can show somebody what it has been doing.
- To attempt anything it gives itself to do through four escalating rungs
  (`005`), and to say which rung it reached.
- To write down what it is doing and what the things it built do — in whatever
  form, at whatever length, and as often as it decides is worth the room (`004`).
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
   → open a channel on each part    now it can act on the world, and be seen
   →
   ↻ GROW — nobody is waiting yet                                         005
        build everything it can think of and fit
        ends when one more thing would cost a capability, not a repetition
   →
   ↻ the machine gives itself something to do
        can what is here already do it?              rung 1               005
        can something here be altered to do it?      rung 2               005
        make room, and build it                      rung 3               005
        condense, so the room came from duplication  rung 4               005
     anything that might not stop runs on its own thread, and is timed    006
     what arrived from outside is written down, so the machine can
     walk backward into what happened                                     006
```

## Reading order

`001` → `005` → `003` → `004` for the design. `002` and `006` are the two
mechanisms everything else stands on and can be read in either order. `010` is
the one part that arrives rather than being built, and is worth reading before
`003` if the question on your mind is how any of this starts at all. `008` is the
list of what has been decided and what has not, and it is the most useful
document here for anyone about to write code.

## Open questions

Held in `008-open-questions.md`, all of them, so that none of them are buried at
the end of a document nobody opens. It is the running record of what has been
decided, and several things that were settled there have since been un-settled by
a later answer — which is why it says who decided what, and when.
