# 907 — The Narrator Is a Viewer

| | |
| --- | --- |
| Phase | 9 — The Scene |
| Blocked by | 902, 903 |
| Blocks | 908, 910, 912 |
| Reads | [the scene](../docs/010-the-scene.md), [the shape of the code](../docs/011-the-shape-of-the-code.md) |
| Open questions | **20** — when it runs |

## Current behavior

Scene records exist and nothing turns them into words.

## Intended behavior

This project's oldest rule, arriving where it matters most:

> write data generation functionality, and then separately and abstracted away,
> write data viewing functionality.

**The scene generates. The narrator views.** It receives a sealed record and
produces text, and it renders nothing back.

### Three properties, and they are why the arrangement is worth being strict about

**A bad narration is a bad paragraph, not a corrupted city.** Nothing needs undoing
because nothing was changed.

**The same scene narrated twice leaves the city identical.** Run it again for a
better paragraph, run it with a different model, or read the record with no
narrator at all. The world does not notice.

**The city runs headless.** A thousand days, nothing attached, and the result is
the same city. This is the property that makes depending on a language model safe
here at all — the model is a viewer in exactly the sense this project has always
meant, and viewers are allowed to be absent.

### The separation must be visible in the source

[The shape of the code](../docs/011-the-shape-of-the-code.md) already carries the
rule that the shared code must never ask which mode is running it. The same
discipline applies here, harder: **no file that computes a scene may import
anything that produces words, and the narrator may not reach the simulation.**

The moment a scene-building file wants to know what the narration said, generation
and viewing have begun to bleed.

### One exception, and it must not spread

**Naming a minted axis is generation, not viewing** — see
[910](910-naming-is-the-one-place-words-touch-the-world.md). A new name entering the
vocabulary is a real change to the city, because an axis is also a filter and gets
hatched across the map from then on.

Naming and describing are two jobs done by the same thing, and keeping them apart
in the code is what stops the exception from quietly becoming the rule.

### Where it runs is not decided

The game is Lua and LÖVE; a language model is not in the process. Narrating during
a turn means a network call mid-play; narrating ahead of time means batches and
storage. See question 20. Either way [912](912-a-missing-narrator-fails-loudly.md)
applies.

## Suggested implementation steps

1. Give the narrator one entry point taking a sealed scene record and returning
   text. No other parameters, and no handle on anything.
2. Put it in files nothing in the simulation imports, and assert that in the build.
3. Run the headless case in the test suite: a simulated stretch of days with no
   narrator, compared against the same stretch with one, asserting identical city
   state.
4. Test that the same record narrated twice changes nothing.

## Related documents and tools

- [The scene](../docs/010-the-scene.md)
- [The shape of the code](../docs/011-the-shape-of-the-code.md) — generation and viewing stay apart
- [Open questions](../docs/013-open-questions.md) — question 20
