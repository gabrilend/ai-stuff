# 201a — Reading something too big to hold

## Current behavior

**Done, and tested** — `src/066` reads, `src/067` checks it, 19 of 19 on
2026-08-02, including the seam with the hands: a hand answering with
thirty-five thousand characters crossing as one labelled piece under six
hundred.

The judgement is handed in rather than built in. The reader walks windows
and asks the machine a question with a shape that can be answered cheaply —
is what is wanted in here, and should the search widen — because a scan
producing prose about every chunk would cost more than reading the whole
document. What counts as an answer is never the reader's decision.

Cutting prefers a blank line, then a line ending, then a space, each looked
for in the last quarter of the chunk so a cut is never dragged far from
where it was wanted. Content with no boundary anywhere is cut at the byte,
which is correct rather than a fallback: there is nothing meaningful to cut
on.

A single piece crosses as a piece; several pieces are summarised only when
a summariser was given, and the atom then says in words that it is a
summary. Both name which pieces of how many they came from, and both carry
`derived_from`, so the machine can go back for more.

An empty result distinguishes *the whole thing was read and none of it
answered* from *the search itself failed*, which are different facts and
were worth separate sentences.

The second context this needed turned out to cost nothing: the loop keeps
everything a machine thinks with in one object, so a scratch context is a
second object rather than a mode.

## Intended behavior

Large results are searched in a **scratch context** and only the useful part
crosses into the machine's own. The main context sees three or four valuable
chunks rather than the whole document, and never has to know how large the
document was.

## The mechanism

```
a call returns something too large
   → build the question: the specific request, plus whatever context is
     needed to understand the item being looked at
   → chunk the result
   → fill a scratch context with as many chunks as fit and ask:
        is what we need in here?
        if not, does the search need to widen?
   → swap those chunks out, swap the next ones in, ask again
   → repeat until the whole thing has been passed over
   → return the chunk or chunks that had it, as text, possibly
     summarised together
```

The sizing is the part that makes it work. **Chunks are about a tenth of a full
context each, and seven to nine of them are resident at a time** — depending on
how much room the question and the answer need. That fills the scratch context
without crowding out the asking, and it means a document of any size is covered in
a predictable number of passes.

## Suggested implementation steps

1. Provide a second context for this. The engine has to be able to think in a
   scratch context that is filled, used and discarded, without disturbing the
   machine's own — which is a requirement on `105` that did not exist before.
2. Chunk on something meaningful where the content allows it — lines, records,
   sections — rather than on a byte count that cuts words in half.
3. Ask a question with a shape that can be answered cheaply: does this contain
   what is wanted, and if not, should the search widen. A scan that produces prose
   about each chunk costs more than reading the document would have.
4. Return the found chunks as an atom, with `derived_from` naming the source, so
   the machine can tell later where the text came from and go back for more
   (`docs/013`).
5. Summarise several chunks into one where the answer spans them, and say that
   summarising happened. A summary presented as a quotation is a lie the machine
   told itself.

## What it does not solve

**An answer that needs the first chunk and the last one together.** Each pass sees
a window, so a relationship spanning the whole document is invisible to every
pass. This is known and accepted for now; the honest mitigation is that a widened
search can carry findings forward, and the honest admission is that some questions
will come back wrong rather than unanswered.

## Blocks

Nothing formally. In practice `203`, `206` and anything else that can return more
than a screenful.

## Blocked by

`201`, `105`.

## Related documents

`docs/013-datapath-the-context.md` — atoms, and what the main context is allowed
to contain.
