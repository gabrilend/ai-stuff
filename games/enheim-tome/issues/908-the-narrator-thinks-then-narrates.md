# 908 — The Narrator Thinks, Then Narrates

| | |
| --- | --- |
| Phase | 9 — The Scene |
| Blocked by | 905, 906, 907 |
| Blocks | 909, 911 |
| Reads | [the scene](../docs/010-the-scene.md) |
| Open questions | — |

## Current behavior

The narrator receives a scene and writes about it. It either sees everything, and
leaks, or sees only permitted facts, and writes ignorant prose.

## Intended behavior

**Two phases.**

| Phase | Sees | Produces |
| --- | --- | --- |
| **thinking** | **everything.** All facts, all history, public and private alike | what this scene is about |
| **narration** | public facts, plus private ones the reader knows | the words |

> the narrator sees everyone's history but facts about a person can be sorted into
> "public" and "private" and knowing a private thing about a person lets that be
> included in the output. There should be a "thinking" phase and then a "narration"
> phase - the thinking should include all the facts, while narration should only
> include public and known facts.

### Why two phases rather than one filtered pass

The question this answers had assumed a choice between an ignorant narrator and a
leaky one. Two phases refuse the choice.

They give the thing people actually do: **you know something, you do not say it,
and knowing it changes how you say everything else.** The thinking phase can shape
a paragraph around a private fact without stating it, which is what discretion is,
and no single-pass arrangement produces it.

### What the reader is

The narration is written for somebody — the person being played — and *known*
means known **to them**. Switching person therefore changes the words as well as
the map, from the same rule, which is the same thing character switching already
did to the hatching.

### The trap

Two phases sharing one context is not a boundary. See
[909](909-the-narration-phase-cannot-see-the-private-facts.md), which exists
entirely because this ticket is easy to implement in a way that only appears to
work.

## Suggested implementation steps

1. Take the reader as an explicit parameter alongside the scene. It is never
   implicit and never global.
2. Run thinking against the full record, including every actor's history.
3. Filter the thinking phase's conclusions through the visibility test from
   [906](906-a-fact-is-public-or-private.md) — the same test the filter reading
   uses, not a second copy.
4. Run narration against the filtered conclusions only.
5. Test with a scene containing a private fact the reader does not know, asserting
   it is absent from the words but that the words differ from the same scene with
   the fact removed entirely. That difference is the discretion working.

## Related documents and tools

- [The scene](../docs/010-the-scene.md)
- [906 — a fact is public or private](906-a-fact-is-public-or-private.md)
- [909 — the narration phase cannot see the private facts](909-the-narration-phase-cannot-see-the-private-facts.md)
