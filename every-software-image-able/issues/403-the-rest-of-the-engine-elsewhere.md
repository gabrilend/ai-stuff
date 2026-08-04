# 403 — The rest of the engine, on the other two machines

## Current behavior

**The three architectures agree about thinking and disagree about
everything either side of it.**

What exists on all three, each proved against the first architecture bit for
bit on a real emulated machine:

| | Proved by |
|---|---|
| the eleven arithmetic routines | 279 of 279 values, and 133 normalisation values |
| the conducting -- layers, heads, every pointer | 192 of 192 scores, over a whole prompt |
| the sampler -- scores into a chosen word | 620 draws, plus ending at the same place in the carried file |
| the waking code -- which processor, which engine | 18 of 18, by booting two processors and requiring them to disagree |

What exists on the first architecture only:

| | Why it matters |
|---|---|
| **the tokenizer** | text into the model's numbers and back. Without it a machine can think and cannot be told anything, because what it was told is text |
| **saying something** | the console. Without it a machine can think and cannot be heard, which also means it cannot be diagnosed |

Both are assembly, both are called by the driver (`107`), and neither exists
for the second or third architecture.

## Intended behavior

Both written for the other two architectures and held to the first the way
everything else here is: the same inputs, the same recorded answers, compared
as integers on a real emulated machine.

## Why these two and not the hands

The hands -- memory, storage, ports, status, running what it wrote -- are a
different question and are deliberately not in this ticket. They are still
the readable kind of code everywhere, including on the first architecture, so
porting them is not the next step; writing them once in assembly is, and
where that happens is `107`'s step nine.

These two are different because they already exist in assembly on one
machine, the driver calls both on every single turn, and neither can be
deferred: a machine that cannot turn text into numbers cannot read the
instruction it woke up holding, and a machine that cannot say anything cannot
report why it stopped.

## What each will cost, honestly

**Saying something is small and shaped by the firmware, not the processor.**
It writes characters through a console the firmware hands over, and this
project already does that on all three architectures in every payload it has
booted -- the console lives at a fixed offset of the firmware's table, and
the routine that writes a string is at a fixed offset of the console. The
work is a routine that walks a byte string and widens it, plus the framebuffer
half, which is drawing letters as pictures and is the same arithmetic
everywhere.

**The tokenizer is the larger of the two and is pure bookkeeping.** No
floating point at all: it walks a byte string, looks pairs up in a prepared
table, and merges the best-ranked pair repeatedly until none is left. Being
integer work throughout, it ports mechanically -- but it is also the one
piece whose failure mode is a *wrong answer that looks fine*, because a
tokenizer that merges in a slightly different order still produces numbers,
and the machine reads a subtly different instruction.

So it is held to the corpus the first architecture is held to: the awkward
cases where tokenizers actually disagree with each other, and refusals
required at the same places.

## Suggested implementation steps

1. Do the tokenizer first. Saying something can be worked around during
   development by reading memory from outside (`703`); being told something
   cannot.
2. Hold both to recorded answers, not to a readable twin running on the
   guest. The answers come from the first architecture and are carried into
   the payload as bytes, exactly as `100`, `113` and `119` do it.
3. For the third architecture, remember that every branch goes through the
   word emitter (`054`) and that the finished object must have no relocation
   left in it. The test refuses to boot one that does.
4. Expect the console to want a decision the other two did not: what to do on
   a board with no framebuffer at all. `601` names that case and it is not
   this ticket's to answer, only to not assume away.

## Blocks

`107` on any architecture but the first, and therefore first light anywhere
but the first.

## Blocked by

`401` for the arithmetic and the conducting these sit above, which is done.

## Related documents

`docs/010-datapath-the-mind.md` — writing the same program three times as the
price of not having a compiler.
`docs/102-adding-a-new-machine.md` — which of three situations a new machine
is in, and which of them is real work.
