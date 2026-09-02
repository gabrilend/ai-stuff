# 909 — The Narration Phase Cannot See the Private Facts

| | |
| --- | --- |
| Phase | 9 — The Scene |
| Blocked by | 908 |
| Blocks | — |
| Reads | [the scene](../docs/010-the-scene.md), [the shape of the code](../docs/011-the-shape-of-the-code.md) |
| Open questions | **24** — how the boundary is enforced |

## Current behavior

The narrator thinks with everything and is asked to narrate with less. Both phases
run against the same context, so the private facts are still in front of the model
while it writes.

## Intended behavior

**The boundary is structural, not requested.**

If the two phases share a context, *"narration should only include public and known
facts"* is an instruction the model is asked to follow. It will follow it most of
the time. The times it does not are exactly the times nobody notices — a private
fact appearing in prose reads like ordinary writing, and there is nothing to
compare it against.

[The shape of the code](../docs/011-the-shape-of-the-code.md) already names this
class of failure and forbids it:

> **Prefer a loud failure to a quiet substitution.** A fallback nobody has noticed
> is a bug that has been running for months.

A discretion boundary held by asking nicely is precisely that.

### What replaces it

**The narration phase runs against a context that never held the private facts at
all** — only the thinking phase's conclusions, themselves passed through the same
visibility test.

What cannot be seen cannot be leaked. The guarantee then holds by construction,
and it holds even if the model is changed, misbehaves, or is prompted badly.

### It is the only place correctness depends on something outside the program

Everything else in this design is arithmetic that can be replayed and asserted on.
This one boundary is enforced against a thing that does not behave deterministically
and cannot be tested exhaustively — which is the reason to make it a matter of what
is in the context rather than a matter of what was asked for.

### The cost

The narration phase cannot reach back for a detail it turns out to want. If the
thinking phase's conclusions omitted something, the words are written without it,
and the fix is in what thinking passes forward rather than in letting narration
look.

## Suggested implementation steps

1. Make the two phases separate calls with separately constructed contexts. Never
   one call with an instruction to self-censor.
2. Construct the narration context from the filtered conclusions alone. The scene
   record and the histories must not be reachable from it.
3. Assert it in the build: the narration context, serialised, must contain no
   private fact for that reader. This is a test that can actually fail.
4. Test with a private fact whose text is distinctive, asserting it never appears in
   the narration context at all — not merely absent from the output.

## Related documents and tools

- [The scene](../docs/010-the-scene.md) — the trap, stated
- [The shape of the code](../docs/011-the-shape-of-the-code.md) — fallbacks are warnings, warnings are errors
- [Open questions](../docs/013-open-questions.md) — question 24
