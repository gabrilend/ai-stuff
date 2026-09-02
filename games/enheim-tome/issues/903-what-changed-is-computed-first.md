# 903 — What Changed Is Computed First

| | |
| --- | --- |
| Phase | 9 — The Scene |
| Blocked by | 812, 902 |
| Blocks | 904, 907 |
| Reads | [the scene](../docs/010-the-scene.md) |
| Open questions | — |

## Current behavior

A scene record has a field for what changed. Nothing guarantees it is filled in
before anybody is asked to describe the scene.

## Intended behavior

**The outcome is computed before the narrator is ever asked.** The narrator is told
what happened and writes it up; it is not consulted about what should happen.

An axis moves because the share of one over N+1 says it moved — see
[812](812-the-closed-give-and-the-open-adopt.md) — never because a sentence said
somebody was persuaded.

### This is the ordering the whole design rests on

It is small to implement and easy to break, and breaking it is not recoverable by
patching later, because once the words decide anything the city stops being
computable. A run cannot then be replayed, tested, or reasoned about, since the
thing that decided it cannot be re-run to the same answer.

So the ordering is not a preference about code layout. It is what makes every claim
in [907](907-the-narrator-is-a-viewer.md) true.

### What it costs

The narrator cannot make a scene more interesting. If a gathering produced a dull
outcome, the words describe a dull outcome. That is the trade, and it is the right
way round: a system where the storyteller can improve the facts has no facts.

## Suggested implementation steps

1. Fill `changed` during the gathering's arithmetic, in the same pass that applies
   the blend.
2. Seal the scene record before it is handed anywhere. A narrator receives a value
   it cannot write back to.
3. Give the narrator no handle on the simulation at all — not a callback, not a
   reference, nothing it could ask a question through.
4. Test that running a day with the narrator attached and a day with it absent
   produce byte-identical city state.
5. Test that the same scene narrated twice leaves the city identical, which is the
   observable form of this rule.

## Related documents and tools

- [The scene](../docs/010-the-scene.md)
- [812 — the closed give and the open adopt](812-the-closed-give-and-the-open-adopt.md) — where the arithmetic lives
- [907 — the narrator is a viewer](907-the-narrator-is-a-viewer.md)
