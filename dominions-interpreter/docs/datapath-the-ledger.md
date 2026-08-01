# Datapath — the ledger

*The intended moves, written so a person can read them, keep them, correct
them, and if necessary type them in by hand.*

## The ledger is the product

The vision says *"It should save the intended moves and resolve them using the
actual game system"*. Those are two things, and separating them is the most
important structural decision in this project.

Saving the intended moves is cheap, certain, and useful on its own. Resolving
them means writing bytes into an undocumented binary format, which is neither
cheap nor certain. Binding the two together would mean that until the hard half
worked, the easy half produced nothing.

So the ledger stands alone. **A ledger read aloud is a playable turn** — a
person types it into the game and plays it. That makes every phase before the
hand a usable program rather than a step towards one, and it means a failure in
the writer degrades the system to "you have to type it in" rather than "you
have nothing".

## What an entry looks like

Plain text, one entry per stanza, hand-editable, diffable.

    commander  Cheiron
    standing   Ancyrna
    order      move to Two Spruce Forest
    because    "have Cheiron fall back towards the forest before the thaw"
    said-at    chronicle line 4471

Four of those fields describe the move. The fifth is the one that makes the
format worth having.

## Every order names the sentence it came from

`because` holds the actual words that produced the order, and `said-at` points
at the chronicle line they were said on.

This is not an audit trail added for tidiness. It is the mechanism by which an
invented order becomes visible. A conversation engine's characteristic failure
is producing a plausible order nobody asked for — the model rounds a discussion
about defending the north into a specific march, and the march looks exactly
like every other line in the file.

With provenance required, it does not. An entry whose `because` does not
correspond to something a person actually said is findable by reading, and
findable mechanically by checking the reference. An entry that cannot cite is
rejected by the steward before it is written.

The person reviewing a turn is therefore reviewing *"here is what I am about to
do, and here is why I think you asked for it"*, which is a much easier thing to
check than a list of moves.

## Validation happens against the world, not against the model

Before an entry is accepted:

| Check | Against |
|---|---|
| the commander exists | the court |
| the commander is where the entry says | the world table |
| the destination exists and is adjacent | the world table |
| the order is one the writer can express | the hand's current vocabulary |
| the citation resolves | the chronicle |

All five are lookups. None of them ask a model whether the order is sensible —
that is the person's job, and asking a second model to approve the first one's
work produces confidence rather than correctness.

The fourth check is the honest one. The hand's vocabulary starts small and
grows as each order type is established by experiment. An order the ledger can
express but the hand cannot write is **accepted into the ledger and marked**,
because it is still a real intention and still belongs in the turn a person
types in by hand. The ledger is allowed to be ahead of the writer.

## Review, and the shape of the accessible surface

At the end of a conversation the whole ledger is read back in order, in
sentences, and the person is asked to confirm, change, or drop entries by name.

That read-back is the last checkpoint before anything is written, and it is
designed for being listened to rather than looked at: one entry at a time, each
self-contained, no reliance on position or colour, and every entry addressable
by the commander's name, which is the same handle used to create it. Nothing in
the review requires holding a list in your head.

## What it is not

Not a save format for the game, not a replacement for the `.2h`, and not a
scripting language. It records intentions in the vocabulary the conversation
used. The translation into the game's terms happens once, downstream, in the
hand — and the ledger keeps its own words so that when a translation turns out
to be wrong, what was meant is still there to translate again.

## Related

- [The hand datapath](datapath-the-hand.md) — what turns a ledger into a turn
- [The chronicle datapath](datapath-the-chronicle.md) — what `said-at` points into
- [The doors datapath](datapath-the-doors.md) — the steward, which writes these
