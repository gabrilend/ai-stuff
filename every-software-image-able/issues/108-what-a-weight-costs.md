# 108 — What a weight costs, said once

## Current behavior

**Three files hold the same fact and none of them agree.**

| Where | What one weight of the smallest carried form costs |
|---|---|
| the packed-model format | `bytes = 0` |
| the memory budget tool | `(16 + 2) / 32` — 0.5625 bytes |
| the engine | four, because it reads nothing else |

The format's zero means "no fixed per-number size, it is block-quantised."
It sits in a field called `bytes`, beside three entries where the number is
literal, so anything reading that table and multiplying by a weight count
gets nothing at all.

The budget tool's 0.5625 is right for the form it names: thirty-two weights
share one scale, so four bits each plus a sixteen-bit scale spread over
thirty-two of them.

The engine's four is right for what the engine does, which is read plain
thirty-two bit floats and nothing else.

**So every answer this project has produced about whether a machine fits was
computed with a number the engine cannot honour.** The tool reports that a
model of about a billion weights costs 590 MB and fits a small board. Through
the engine that model is 4.2 GB and fits nothing.

**The reason for the engine's limit is written down and is not the reason
that gets repeated.** The format file says it plainly: a block-quantised form
"puts a dequantise step inside the hottest loop in the machine, which is
assembly nobody wants to write three times." That is a cost, honestly stated.

What gets repeated instead is the *fixture's* reason -- that a fixture which
quantises is a fixture with an opinion. That is true and good and it is an
argument about the recorded answer everything is measured against, which
should be as plain as possible. It was never an argument about the engine.
The principle was borrowed from next door and worn over the top of a cost.

## Intended behavior

**One description of what a weight costs**, read by everything that needs it,
so that a disagreement is impossible rather than merely unlikely. And an
engine that can read the small form, so that the boards the budget tool plans
for are boards the machine runs on.

## Why this is the fourth of its kind

Four times in two days, the same shape: two descriptions of one fact that
have never been in the same room.

| | |
|---|---|
| the list of routines still to write, against what the first architecture had | the fast matrix product was missing from a port reported as finished |
| the phase summaries, against their own rows | three phases read as complete when the half that runs on the chip was not written |
| the budget tool's bytes-per-weight, against the engine's | every fitting answer computed against something unimplementable |
| the format's bytes-per-weight, against the budget tool's | a factor of infinity |

This project already has the rule that prevents it -- **one description,
nothing counted by hand** -- and enforces it rigorously where somebody
remembered to: the conducting's plan is checked slot by slot against what the
host believes, and the image builder refuses to write a layout the engine
does not expect. Both of those are the same idea applied by hand, in one
place each.

The pattern is worth naming because the next one is already somewhere.

## Suggested implementation steps

1. **Make the format the one description.** It is the file that decides what a
   stored number *is*, so it is where the cost belongs. Replace the `bytes`
   field for the block-quantised form with something that cannot be
   multiplied by a count and silently give zero -- a cost per block and a
   block size, so a reader has to know it is asking about blocks.
2. **Have the budget tool ask rather than hold.** Its own table goes; it reads
   the format's. Then the two cannot drift, and the tool reports what the
   machine would actually do.
3. **Have the budget tool ask the engine what it supports**, and mark any
   form the engine cannot read. A tool that plans in a currency the engine
   does not accept should say so on the same line, not in another file.
4. **Then write the dequantising matrix product**, on all three
   architectures as one piece of work rather than one and two ports (`403`
   states why).
5. **Give it its own recorded answers.** Applying a shared scale is another
   place where the order of operations *is* the answer, so it is a fourth
   specification alongside the exact product, the four-at-a-time one and the
   four-totals one -- not a smaller version of any of them. Held to the first
   architecture bit for bit like everything else.

## What this unlocks, in real numbers

The small-hardware case the budget tool already plans for and the engine
cannot run.

A machine with a gigabyte of memory can hold a model of about a billion
weights in the small form -- 590 MB of weights, 88 MB of cache at a context
of 2048, and working space under a quarter of a megabyte. At the engine's
measured rate, and allowing for a processor a hundred times slower than a
desktop, that is **one to two minutes a token**, which is a usable machine
for anyone willing to wait.

And memory does not cap the model. It caps the **context**, because what must
stay resident is the cache of everything thought so far. A model far larger
than memory runs with its hot parts resident and the rest read in place off
the medium, which is what the four rungs are for. On the same gigabyte, a
seven-billion-weight model with its context cut from 8192 to 512 needs about
128 MB of cache and 725 KB of working space, and streams roughly four
gigabytes off the card per token -- about sixty-six megabytes a second, which
an ordinary card sustains.

**Short thoughts, big model, slow.** Not: small model.

## Blocks

Nothing that is being built. It decides which machines the seed can run on at
all, which makes it a phase 1 question rather than a phase 5 one.

## Blocked by

Nothing.

## Related documents

`docs/005-datapath-the-four-rungs.md` — what to do when it does not fit.
`docs/001-concept-overview.md` — what this is for, and on what.
`notes/014-spoken-while-building.md` — where this was noticed, and how.
