# 403 — The tokenizer and the console, on all three at once

## The rule this ticket is written under

**Every piece of assembly is written for all three architectures as one piece
of work.** Not one, then ported twice. This ticket was first drafted as
"port the stragglers" and that framing is the thing being corrected.

**It is not about fairness between machines. It is about what goes wrong.**

*A list that is written once and consulted later goes stale in between.* The
fast matrix product was absent from the second architecture for weeks and
nothing reported it, because the first architecture had it, the second was
written later against a list of what was still to do, and that list had been
emptied when the port felt finished. Written together there is no "later" for
a list to go stale in, because there is no list.

*A second implementation catches what a recorded answer cannot.* This project
learned that directly: composing the arithmetic found a rounding defect that
was in the **reference**, and no fixture could have caught it, because the
fixture was produced by the thing that was wrong. Implementations written
side by side check each other continuously. Written in sequence, they check
the first one twice and late.

*Decisions get frozen by whichever machine went first.* The first
architecture reaches devices through a separate address space with its own
instructions; the other two are memory-mapped throughout. The third has no
vector hardware on the processor its board names, and where such hardware
exists it stays switched off until something with machine-mode privilege
enables it. Both are design questions that belong at the moment a routine is
designed, and both were discovered while porting.

*And the text carried on the chip drifts the same way.* The bundled patterns
told every machine that arguments arrive in the first architecture's
registers, on all three cards, for as long as there were three -- because
they were written when there was one. That one is now fixed and refuses to
be written without knowing which processor the card is for.

**What stays sequential is a different axis: first light on physical
hardware.** Getting one board working before three is not about writing code
for one architecture first. It is that integration on real hardware fails for
reasons which have nothing to do with the instruction set, and finding those
on one board is cheaper than on three (`601`). Write in parallel; debug on
one board.

---

## What this ticket covers

## Current behavior

**The tokenizer is done on all three, 2026-08-04.** Written for the second
and third architectures as one piece of work, and held to the first over the
corpus where tokenizers actually disagree -- plain prose, runs of spaces, a
leading space, only spaces, a newline and a tab, a null byte in the middle,
bytes above 127, one character, nothing at all, and text that is entirely a
single token. Both directions: the same numbers out, and the same bytes back
again. 9 of 9 in `src/127`.

The decode half is checked as hard as the encode half, and that is not
symmetry for its own sake -- a tokenizer whose two halves are wrong in
matching ways round-trips perfectly while saying something else entirely.

**And the console is done on all three, the same day.** Saying something is
now a routine anything can call rather than words spelled out inline when a
payload is built -- which is the form an engine needs, because an engine says
whatever a model produces and cannot know it in advance. 9 of 9 in `src/129`,
on real emulated machines of both kinds.

Three things are checked beyond "something appeared", each of which a routine
that merely looked right would fail: a message several times longer than the
scratch it is given, so the chunking is exercised rather than assumed; the
pieces required to arrive in order and joined, so a routine that returned
early or restarted is caught; and bytes that are not letters, since widening
is where a routine that sign-extends rather than zero-extends turns anything
past 127 into a different character entirely.

**One thing had to be shuffled on the first architecture and not the other
two.** Firmware there is called by a different convention than the rest of
that architecture's code uses -- arguments in c, d, r8, r9 rather than di,
si, d, c -- and it expects thirty-two bytes left below the return address
that it may use and this routine never reads. On the other two, firmware is
called exactly the way everything else is.

**What this ticket does not cover, deliberately: the screen.** Drawing
letters as pictures exists on the first architecture only, and a board may
have no display at all -- which `601` names as a case to meet rather than
assume away. The wire is the channel that always exists, and it is the one
that matters while something is going wrong.

**This ticket is complete.**

---

**The state this ticket was written in. The three architectures agreed about
thinking and disagreed about everything either side of it.**

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

Both existing on all three, held to the same recorded answers, compared as
integers on a real emulated machine of each kind.

That the first architecture already has them is an accident of when they were
written, not a head start to be preserved. If either turns out to want a
change -- and the tokenizer might, since nothing has yet asked it to run
where there is no allocator -- the change is made in all three, at once,
rather than in one and then chased.

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
