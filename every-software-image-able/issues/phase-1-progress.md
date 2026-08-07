# Phase 1 — The engine

**Goal.** A model that thinks on bare hardware, with no operating system beneath
it. Weights in, tokens out, at a measured rate on a real board.

Nothing else in the project means anything until this works. A model that cannot
be run is a file.

**Reopened 2026-08-04.** It was called complete on the first architecture on
2026-08-02, and the claim was one word too broad.

The packed model, the finding of it, the arithmetic, the conducting, the
sampler and the tokenizer are all assembly on x86-64, each held to a readable
twin with no tolerance anywhere. That part stands.

**The loop that closes them into one machine is not assembly.** It runs on
the development machine and reaches the assembly by loading it as a library
and calling in — which proves the assembly is right and cannot go on a card,
because a bare machine has nothing to run it with. So a flashed machine today
detects its processor, says "handing over", and halts.

That is `105`, reopened, and `107`, which is new: the loop's assembly twin
needs to do three things the readable one never had to, because a
foreign-function interface did them for it — find its own pieces with no
linker, find the model's tensors, and lay out memory with no allocator.

**On 2026-08-07 that twin arrived on the first architecture.** A computer
with no operating system reads what it was told, thinks about it, and says
six words — the same six the readable loop says from the same text with the
same carried randomness. The loop is real assembly on real hardware, and what
`105` is now waiting on is the other two architectures rather than existence.

A fourth thing turned up that nobody had listed: the tokenizer's prepared
tables were host code too, built with hash lookups and string comparison, and
the engine's think-time half had been written never to touch a string
precisely so that something else would pay that cost at startup. Nobody had
written the something else.

**The distinction that was missing** is between the two kinds of code here.
Assembly runs on the chip. A readable program runs on the development machine
and proves the assembly. The project's method is to write the readable one,
record what it produces, then write the assembly and require it to reproduce
those answers — and that method has been applied thoroughly at the bottom and
not yet above it.

## Issues

| | | Status |
|---|---|---|
| `101` | Package a model, whichever one | **completed** — 10 of 10 round-trip checks, re-verified with the full suite before closing |
| `102` | Find the weights without a filesystem | **completed** — finding, memory map and ratchet on all three architectures, 27 of 27 against the host's arithmetic |
| `103` | The arithmetic, in assembly | **completed** — nine kernels bit-exact 37 of 37; the conducting in assembly too, 6 of 6; a whole thought is assembly end to end on x86-64 |
| `104` | Sampling, and the carried seed | **completed** — reference respecified to single precision and exact integers, 9 of 9; assembly agrees choice for choice over fifteen thousand draws, 8 of 8 |
| `105` | The thinking loop, and its limits | **reopened** — its assembly twin exists on the first architecture and says the same words, 33 of 33; the readable loop stays the reference, and this waits on the other two tongues rather than on existence |
| `105a` | The tokenizer | **completed** — reference 21 of 21; assembly agrees on the whole awkward corpus, 17 of 17 |
| `106` | Measure the engine | **completed** — 1.36 G multiply-adds/s conducted end to end; three boards timed from power to their own memory report; results kept as data |
| `107` | The driver, and what a machine cannot be told | **in progress** — eight of its ten steps done on the first architecture and four of them on all three; what remains is noticing that what was said is a request |
| `107a` | The loop, on the metal | **in progress** — a machine with nothing underneath it reads, thinks and speaks, word for word what the readable loop speaks, 33 of 33; its three open questions are unanswered |
| `108` | What a weight costs, said once | **completed** — one description, asked by everything that needs it; and the engine reads four-bit weights on all three architectures, agreeing bit for bit, 9 of 9 |

## Where the risk was, and what it turned out to be

`103` was named the largest single piece of work, and was. The reference
comparison built alongside it earned its keep twice over: composing the
kernels found a rounding defect in the *reference*, and the sampler's
respecification caught an integer generator that quietly was not one.

`105a` was named the quiet one. Its assembly half agrees with the readable
half across the whole awkward corpus, so the mild-stupidity failure now
requires both implementations to be wrong identically.

The risk nobody named: integration. Closing the loop caught a separator in
the context that belonged to no atom — each part correct alone, and the
machine they made subtly wrong together.

**And it caught the same shape again on 2026-08-07, in the fixture itself.**
The packed model carried a word-list of placeholder names and two merge rules
joining texts no token held. The blob round-tripped. The tokenizer passed
seventeen checks. Neither noticed, because the tokenizer's tests build their
own vocabulary in memory and never ask the blob for one — so the two halves
had never met. The first program that needed all of the model's sections at
once found it in a second. Sections that are each well-formed alone and
unusable together is the exact shape this phase has now met twice.

And a second one nobody named, found on 2026-08-04 while looking for what to
port next: **the phase was reported complete on a reading of "exists" that
did not distinguish between code that runs on the chip and code that proves
it.** Every claim in the table was true. The summary above them was not,
because the loop was counted alongside the arithmetic and only one of them
can be put on a card.

Nothing was hidden and nothing was wrong — the readable loop is genuinely
proved and genuinely necessary. What was missing was a word. It is worth
recording because the same reading applies to phases 2 and 3, where the same
correction has been made, and because a summary that aggregates two kinds of
thing is exactly the shape of a progress note nobody re-reads.

## What is not decided here

Which model. That is a parameter of the build utility, chosen by whoever makes an
image, and this phase only has to be able to carry whichever one arrives.

## Demo

`issues/completed/demos/phase-1-the-engine.sh`, chosen through `run-demo` at
the project root: what fits (`046`), how fast it thinks (`051`), and the
boards from power to speech (`063`). Numbers, not descriptions, and the
tools keep their results as data so none of them go stale in a document.
