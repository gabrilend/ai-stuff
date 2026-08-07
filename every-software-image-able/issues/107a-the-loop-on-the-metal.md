# 107a — The loop, on the metal

A sub-issue of `107`. That ticket lists ten things the driver must do in
order; `107` itself carried steps one through four to completion. This one is
steps **five through eight**: read what the machine was told, turn it into
numbers, run the engine and draw a word, say it, and go round again.

Step nine — noticing that what was said is a request, and carrying it out —
is deliberately left out. `107` predicted it would want its own ticket once
its shape was known, and it does: recognising a request means comparing byte
strings against a catalogue, which is a different kind of work from
everything here.

## Current behavior

**Done and proved on the first architecture, 2026-08-07, except for the open
questions below.** A computer with no operating system reads what it was
told, turns it into numbers, runs the engine, draws a word, says it, thinks
about it and draws another — and says the same six words the readable loop
says from the same starting text with the same carried randomness.

`src/137`, checked by `src/138`, 17 of 17: the tokenizer's four tables, built
by the machine from the word-lists its model carries, identical to the host's
byte for byte, with both refusals landing and the right number beside each.

`src/139`, checked by `src/140`, 33 of 33: the sampler's setup, the loop, and
first light. Eighteen of those checks run on the development machine, where a
failure can be pointed at. Fifteen run on an emulated board, which is the
claim that matters.

What the board said: twenty-two tensors found, five thousand three hundred
and twelve bytes divided, the plan filled, one thousand three hundred and
twenty-eight bytes of word tables built, seven hundred and sixty-eight bytes
of sampler scratch readied, and then six words — token for token what the
readable loop draws.

**Three things the readable loop never had to do**, because a
foreign-function interface did them, and all three are now written:

**It never built the tokenizer's prepared table.** `059.prepare` is host
code: hash lookups and string comparison, neither of which exists on the
metal. The engine's think-time half was deliberately written never to touch a
string, and the cost of that decision is that something else pays it at
startup. That is `137`, and the expensive part is resolving merge rules —
priced in its own comments and in the open question below.

**It never filled the sampler's two structures.** Now a routine beside the
driver. The slot that matters is the one saying the generator has already
used up its current number, so the first draw fetches from the carried file
rather than sampling four thousand bits of a state nobody set.

**It never found the text region.** The payload carries the model, the
starting text and the carried randomness sixty-four kilobytes past its own
first instruction and reaches each by measuring from where it is standing.
See the first open question: that is honest for a payload and is not how a
shipped card will do it.

**A defect this uncovered, in the fixture, now fixed.** The packed model
carried a token table of placeholder names — `t1` through `t48` — and two
merge rules joining texts no token held. `059.prepare` refuses such a table,
correctly and by design, so **the fixture had always carried a tokenizer
table that cannot be prepared**. Nothing noticed, because the only test that
tokenizes builds its own vocabulary in memory and never asks the blob for
one. Three sections each well-formed alone and unusable together, found
immediately by the first program that needed all of them at once. `036` now
emits single-byte tokens for most of the vocabulary and two multi-byte ones
the merge rules actually produce, so the merge path is exercised rather than
skipped. The recorded answers did not move; the weights never changed.

**What is still readable-only above this**: the hands, the atom context and
the assembler. None is needed to think, and the first of them is step nine.

## Intended behavior

A routine the waking code can jump to that never returns, which reads the
text the image carries, thinks about it, says what it thought, and keeps
going.

The words it says must be **the same words the readable loop says**, given
the same model, the same carried randomness and the same settings. Not
similar — the same, token for token, because a token is discrete: one
different choice at one boundary and the two machines are having different
conversations from that moment on.

## What has to be written

**The tokenizer's preparation, in assembly.** Blob in, the four arrays out,
carved from a run of memory the caller supplies. Its shape follows `133`: it
is handed room and a size, it takes what it needs from the front, and a
machine short of room is told the number of bytes it was short by rather than
quietly given a smaller table.

The expensive part is resolving each merge rule to the token it produces,
which means finding the token whose text equals two other tokens' texts
joined. There is no hash and nothing to build one with, so it is a walk over
the vocabulary per rule. **Where that stops working should be said out loud
rather than discovered**: it is the product of the merge count and the
vocabulary size, which is nothing on a fixture and tens of billions of byte
comparisons on a real model. It is startup-only, it is paid once, and if it
turns out to be too slow the answer is to pay it at build time instead — that
is a decision for whoever first boots a real model, and it should be recorded
where they will find it rather than guessed at now.

**The sampler's two structures, filled in assembly.** Small: the carried
randomness region's address and length, the generator's starting state, three
scratch arrays carved from the same run of memory, and the three settings.

**The loop.** Read the text region. Tokenize it. Lay it into the cache one
position at a time. Then: draw a word, say it, put it back at the next
position, and repeat until a token that means "finished" or a limit.

**A cache that is laid down once and added to.** The readable loop reuses the
longest common prefix of what the cache already holds, because it can be
handed a whole new context between turns. This one is only ever appending, so
it keeps a position and advances it — which is the same arithmetic with none
of the comparison, and it is worth writing down that the simpler form is
correct *only* while nothing rewrites the context underneath it.

## What is deliberately not in here

**The atom context.** `061` reads the context as a concatenation of atoms and
puts what it says back as one. That bookkeeping is the machine's own
(`052`, `docs/013`), and none of it is needed to think. The driver reads the
text region as one stretch of bytes.

**Recovering room when the context fills.** What to let go of is the
machine's decision and always was. The driver stops and says so.

**Finding the regions on a card.** See the open question below. The payload
carries the model, the text and the randomness within itself and reaches them
from the address of its own first instruction, which is step one of `107`
done honestly. What it does not do is read them off a medium, because
nothing yet can.

## How it is proved

The method this project uses everywhere: the readable program is the
reference, its answers are recorded, and the assembly is required to
reproduce them.

1. **The preparation, hosted first.** Build the library, call the assembly
   preparation on a packed model, and compare all four arrays byte for byte
   against what `059.prepare` produces from the same tables. Then encode and
   decode through the assembly-built table and require the same answers as
   the host-built one, because two tables that differ in a slot nothing reads
   are not a defect and two that differ in a slot something reads are.
2. **The whole driver, under emulation.** Build a bootable payload carrying
   the model, a text region and the carried randomness; boot it on the
   emulated UEFI board; and require the tokens it says to equal the tokens
   the readable loop says from the same starting text with the same carried
   file and the same settings.

The second is the one that matters. The first exists because when the second
fails it says nothing about where.

## Suggested implementation steps

1. Give the fixture a tokenizer table that can be prepared — single-byte
   tokens for most of the vocabulary and a pair of multi-byte ones the merge
   rules actually produce, so the merge path is exercised rather than skipped.
2. Write the preparation and prove it hosted, comparing against `059.prepare`.
3. Write the sampler's setup and prove it the same way, against
   `057.new_stream` and `057.new_plan`.
4. Write the loop, and narrate every step of it. The last thing said before
   silence is the entire diagnosis, and all four of the silences in `107`'s
   table were diagnosed by the last mark printed.
5. Boot it, and hold the words to the readable loop's words.
6. Only then quieten the narration, and never before.

## Open questions

1. **How does a driver find the image's regions on a real card?** The builder
   lays down five regions at block boundaries on a raw medium. The boards
   this project has boot through UEFI, where firmware reads one file off a
   FAT filesystem and hands over a pointer to that file's contents in memory
   — so the other four regions are not at a known offset from anything the
   driver can see. Carrying them inside the payload works and is what this
   ticket does. Reading them off the medium means a storage driver, which is
   listed in `107` as the machine's job rather than the seed's. Nobody has
   decided which of those the shipped arrangement is, and `502` cannot close
   without an answer.
2. **Is the merge resolution paid at startup or at build time?** See above.
   The blob format's own note says the token table is "read once at startup
   to build whatever lookup the engine wants," which settles it for now, but
   that note was written before anybody had counted the comparisons.
3. **What does the driver do when the context fills?** It stops and says so,
   which is honest and is also the machine being unable to think any more
   without help. The readable loop has the same limit and the same answer.
   Whether the seed should carry a last-resort behaviour — dropping the
   oldest text, say — or whether stopping is genuinely correct until the
   machine writes its own answer, is not decided.

## Blocks

`601`, `602` — through `107`, which cannot close while its loop is missing.
`502`, which needs real engine bytes to hand its layout check something that
exists.

## Blocked by

`103`, `104`, `105a`, `102` for the pieces it drives, all complete; and
steps one through four of `107`, complete.

## Related documents

`docs/002-datapath-the-interpreter.md` — what the driver is deliberately not.
`docs/010-datapath-the-mind.md` — why a procedure is written down here at all.
`notes/023-what-the-emulator-lies-about.md` — the silences, priced.
