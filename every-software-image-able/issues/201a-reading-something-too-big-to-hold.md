# 201a — Reading something too big to hold

## Current behavior

A call that reads a megabyte returns a megabyte, and a megabyte cannot enter the
thinking loop.

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
