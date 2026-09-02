# 905 — History Is Append-Only

| | |
| --- | --- |
| Phase | 9 — The Scene |
| Blocked by | 807, 902 |
| Blocks | 906, 908 |
| Reads | [the scene](../docs/010-the-scene.md) |
| Open questions | — |

## Current behavior

Scenes are produced and discarded. An actor's present character exists; how it got
that way does not.

## Intended behavior

Each actor carries a record that is **only ever added to**. Nothing in it is
edited and nothing is removed.

| Entry | What it holds |
| --- | --- |
| an **axis change** | which axis, from what value to what value, in which scene |
| a **narration** | the text produced for a scene this actor was in |
| a **minting** | the moment an axis first came into existence, and out of what |

### Why append-only rather than a mutable summary

An edited history cannot be trusted to explain how a thing came to be the way it
is, which is the only job it has. The moment an entry can be rewritten, the record
stops being evidence and becomes an opinion about the past.

It is also what makes a place's character explicable without inference. Walk back
through a block's entries and the sequence of gatherings that made it is all there,
arithmetic and words side by side.

### It is what makes a story rather than vignettes

The narrator receives the character **and** the history. That is what lets the
fortieth meeting between two people read differently from the first — the
difference is in the record rather than in a flag somebody set, and nothing has to
track "have these two met before" as its own state.

### The cost, stated honestly

It grows forever and is never pruned. A city simulated for years accumulates a very
large number of entries, and any pruning scheme would be an edit to history by
another name. If size becomes a problem the answer is where the entries are stored,
not whether they are kept.

## Suggested implementation steps

1. Give the actor record a history list and append to it; provide no update or
   delete operation at all, so there is nothing to misuse.
2. Write an axis change for every movement, naming the scene it happened in, so the
   record and the scenes cross-reference.
3. Write a minting the moment an axis comes into existence, with what it came out
   of — see [815](815-forcing-a-closed-thing-open.md).
4. Report history size per actor and across the city, so growth is measured before
   it is a problem.
5. Test that replaying every axis change from an empty character reproduces the
   present character exactly. If it does not, something edited history.

## Related documents and tools

- [The scene](../docs/010-the-scene.md)
- [807 — an actor is a person or a place](807-an-actor-is-a-person-or-a-place.md)
- [815 — forcing a closed thing open](815-forcing-a-closed-thing-open.md) — where mintings come from
