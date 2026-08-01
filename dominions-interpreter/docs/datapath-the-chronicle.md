# Datapath — the chronicle

*Append-only memory, in which what happened and what was said are never the
same kind of line.*

## Why this exists before anything expensive runs

A conversation about a turn costs many inferences across three machines and
cannot be reproduced. The place it lands has to exist and be trustworthy before
the first token is generated, which is why the chronicle is early in the
roadmap rather than late.

It is also the answer to the vision's *"along with it's previously generated
messages"*. That phrase describes the input; this document describes what shape
that input has to have to be worth feeding back.

## Three kinds of line

One file per game, plain text, one record per line, never rewritten.

| Kind | Written when | Provenance |
|---|---|---|
| `world` | a turn is read | the game |
| `said` | anything is spoken, by either side | the conversation |
| `happened` | a turn resolves | the game |

The kinds are not decoration. **`world` and `happened` are facts; `said` is
not.** A model may be asked to summarise, characterise or connect a `said`
line, but it may not promote one to fact — and because the kinds are separate
columns rather than separate paragraphs, nothing downstream can lose track of
which it is holding.

This is the specific defence against the failure the vision names. A system
whose only memory is its own prose will, after a dozen turns, be recalling
things it said as though they were things that occurred. Keeping the game's
own account in its own kind of line means every conversation is anchored by
outcomes rather than by narration.

## What `happened` holds

The difference between the world before the turn and the world after it,
computed mechanically, plus the game's own event text.

Not a model's summary of the turn. The diff is arithmetic on two world tables —
provinces gained and lost, commanders that no longer appear, history lines that
appeared in a province. It is boring, it is exact, and it is the thing the next
conversation is built on.

There is a second use, and it is the one that makes this project honest about
itself: `happened` can be compared to the ledger that produced it. Orders that
were intended, resolved, and had the intended effect are one thing. Orders that
resolved into something else are worth knowing about, and the record makes that
comparison possible without anybody keeping notes.

## The chain

Each line carries a checksum of itself and the previous line, FNV-1a, cheap to
compute while writing and cheap to walk while verifying.

This is a **tamper-evidence** measure, not a signature. It proves the file has
not been edited in the middle since it was written; it proves nothing about who
wrote it and it is not cryptography. Saying so plainly here is deliberate,
because a chain of hashes described loosely tends to get believed to do more
than it does.

What it actually buys: a chronicle truncated by a crash mid-write can be
recovered up to the last intact link and the damage is located exactly, rather
than a half-written line quietly becoming part of the history.

## The flush discipline

Every line is flushed as it is written. The file is tailable while a
conversation is in progress.

This costs a little speed and buys something the accessibility goal needs
directly: a second terminal, or a screen reader, or a person on another
machine, can follow along without the session having to end first. It also
means a session killed halfway leaves everything up to that point, which for
work this expensive is the difference between an interruption and a loss.

## Reading it back

Two passes, deliberately separate.

**Verify** walks the file and checks the chain. It builds nothing and can run
on a chronicle of any size in one pass with constant memory.

**Load** rebuilds the in-memory history. It assumes the file already verified,
because a loader that also validates is a loader that will one day be asked to
validate loosely.

## What the remembrancer is allowed to do with it

Search it, and cite it. Nothing else.

The remembrancer's whole contract is that every connection it proposes names
the chronicle line it came from, and that lines from `said` are never offered
as evidence of fact. Its output is a small set of candidate links, each with a
line reference, and the pipeline drops any candidate whose reference does not
survive a lookup against the current world table.

It is expected — routinely, not exceptionally — to return nothing. See
`strategems/a-connection-must-name-its-evidence.md`.

## Size

A chronicle grows for the life of a game and is read every turn. Feeding the
whole thing to a model every time is neither possible nor desirable, so what
gets sent is a selection: the recent lines in full, and older lines only where
the remembrancer cited them.

The selection is made before the model is called and is recorded, so it is
always possible to answer "what did it actually know when it said that". A
system that cannot answer that question cannot be debugged.

## Related

- [The doors datapath](datapath-the-doors.md) — who reads the chronicle and what for
- [The ledger datapath](datapath-the-ledger.md) — the other durable artifact, and how they differ
- `strategems/a-connection-must-name-its-evidence.md`
