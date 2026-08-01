# 006 — Datapath: Status and Tolerance

Programs emit a status after every single thing they do. This document is what a
status is, how it is read, and what happens when one goes far enough from
ordinary.

It is the most reused mechanism in the design. The same emission drives the
display, names what the compiler should work on (`004`), and decides when the
machine stops and reasons backward.

## What a status is

Three things: an **aspect**, a **code**, and a **magnitude**.

**Aspect** is which colour and shape the status is shown in, and it says where
the status came from. Behind the display it is a plain integer index. It exists
because the same code number means different things depending on who emitted it,
so the origin has to travel alongside the number rather than being looked up
afterward.

**Code** is a per-program number that can mean whatever that program needs it to
mean. There is no global vocabulary of codes and there is not meant to be. Two
programs may both emit seventeen and mean unrelated things; the aspect is what
keeps them apart.

**Magnitude** is a single axis with **fifty as the zero point.** High or low
values both indicate that attention should be given — and nothing more than that.
It carries no opinion about what is wrong, only that something is further from
ordinary than usual. What the attention should be *about* comes from the code.

**Status**

| Field | Type | Meaning |
|---|---|---|
| `aspect` | integer | which colourshape; where this came from |
| `code` | integer | what is being reported, in this program's own vocabulary |
| `magnitude` | integer | distance from ordinary; fifty is ordinary |
| `occasion` | string | what the program had just done |
| `at` | integer | when |

Two digits each. The whole thing fits on a small array of lamps.

## Why colour and shape rather than words

The display this lands on is a seven-segment readout or a handful of lamps, and
those cannot spell. The origin therefore has to be carried by something other
than letters.

Carrying it as colour **and** shape rather than colour alone means the reading
survives a failed lamp, a dim room, and a person who does not distinguish the
colours. The two encodings say the same thing, on purpose.

## Looking a code up

Codes mean nothing without their definitions, and the definitions are
per-program, so the machine builds a way to ask.

A dispatch table, keyed by aspect and code, returning that code's definition —
rendered as a markdown table. Built from scratch by each machine rather than
shipped, so the query interface is one more thing that differs between two of
these computers. Same principle as the operation table in `002`: look a number up
in a table rather than walk a chain of questions.

This is the standard way to find out what a machine is telling you, and it is the
first thing to build after there is anything emitting statuses at all.

## What moves the magnitude

Repetition. Every instruction the interpreter fetches pushes the magnitude away
from fifty, which is the same countdown standing in for a timer interrupt
(`002`). Crossing a threshold on the way out — sixty-five going up, forty going
down, or whatever granularity is wanted — is what lets the machine notice a loop
that may not end, without having to know in advance whether it was going to.

When a program breaks out of a loop that might have been infinite, the magnitude
returns to fifty. The thresholds it crossed on the way are the record of how close
it came.

The reading lives in memory as a machine-wide, system-agnostic value, so the
picture is comparable across every program at once rather than being a private
number each program keeps to itself.

## Tolerance

Tolerance is one code among many, and it is the one whose extremes stop the
machine. Close to a hundred or close to zero — far from fifty in either
direction — and the machine intercedes.

Both ends matter because the extremes are not the same failure. Near one end a
program has stopped discriminating; near the other it has become brittle. In a
context that is not an error at all, the same distance reads as flexible or as
permitting rather than as either failure. The magnitude does not decide which of
those it is. It says only that a look is warranted, and the code's definition
says what the look is for.

## The same instrument, elsewhere

Processor and accelerator utilisation are each a magnitude in exactly this sense,
reported as two percentages side by side. Fifty is comfortable. Zero says nothing
is happening, a hundred says the thing is pegged, and both are worth a look for
opposite reasons.

So the utilisation display and the status display are the same dial read twice,
which means one reading habit and one place to look.

## Intercession

```
tolerance goes far enough from fifty
   → stop handing new work to the thread pool
   → step through the debugger, with the model reading
   → state how it SHOULD be
   → walk backward through the moments where it could have been set that way
   → co-evolve forward from the branch point
   → work out a new way to program the computer
```

Stopping the thread pool is the load-bearing step and it is easy to overlook. It
is what keeps everything from advancing and overwriting the evidence while the
machine is trying to read it. Without it the history erases itself at exactly the
moment it becomes valuable.

## Walking backward

To step backward through a moment, that moment has to still exist. It cannot be
rebuilt from the current state, because the current state is what lost the
information.

The rule is to **keep track of changes, but only when necessary to
reconstruct** — and there is a precise version of "necessary." The machine only
needs to write down what it could not have computed for itself. Every derived
value is left out, because re-running the same instructions with the same inputs
produces it again for free. What cannot be re-derived is anything that arrived
from outside the machine's own reasoning: a key pressed, a byte read from a
device, a number drawn at random, the moment a piece of hardware answered.

Replay is then: run the same code again from the start, and every time it reaches
outside itself, hand it the recorded value instead of asking the world again. The
machine walks the identical path, into the identical failure.

The cost difference is large. A photograph of memory costs whatever the machine
is holding, per moment. A list of things that arrived from outside costs bytes
per moment, because a machine spends nearly all of its time computing rather than
receiving.

**A cheaper reach, deferred.** Ring buffers give a short window backward for
nothing: memory that has been released still physically holds its values until
something overwrites them, and a buffer written in a circle keeps the previous
lap intact ahead of the write cursor. How far back that reaches is buffer length
divided by write rate. Each slot needs a lap number beside its value, so a reader
can tell "this is the old value I wanted" from "this slot has already been
reused." That belongs to a later stage and is held in `notes/007-deferred.md`.

## Co-evolving forward

Going back to a checkpoint and moving forward along a different branch. Once
there is both a path that happened and a state that was wanted, curve fitting and
similar tools work out what would have had to be different to reach the intended
state. Then the parts of the code that could produce such a state are examined,
and modified if desired.

That imposes one requirement, cheap now and expensive to retrofit: **values must
carry where they came from.** Fitting returns a number — this should have been
nearer seventy — and that is unusable unless something knows which code produced
the value. The aspect index that already rides alongside every status is the same
size and shape as what is needed here.

When the fit has nothing to vary, the answer is not a wrong number. It is the
discovery that the code needed does not exist, which is the trigger for rung
three (`005`).

## Open questions

- **Are the thresholds per-program or per-machine?** The magnitude is described
  as a machine-wide reading, but the repetition that moves it is spent by one
  program at a time. A machine-wide number moved by whichever program happens to
  be running reports the machine's busiest tenant, not its condition.
- **Does every code's definition have to exist before the code is emitted?** A
  program can emit a number the lookup table does not know about, and a status
  nobody can define is a lamp lit for no stated reason.
- **How does a status get emitted before there is a display?** Programs emit
  after everything they do, from very early, and both the display and the lookup
  table are software that has to be built.
- **What retires a gravestone?** `003a` writes intent before a dangerous
  experiment; the same store would hold the moments this document walks backward
  through. Whether they are one store or two is question 10 in `008`.
