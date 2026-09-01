# 312 — A Map Is a Bundle

| | |
| --- | --- |
| Phase | 3 — The Tracing Mode |
| Blocked by | 201, 301 |
| Blocks | — |
| Reads | [the tracing mode](../docs/005-the-tracing-mode.md) |
| Open questions | — |

## Current behavior

A painting is loaded from one place and a network from another. Nothing ties them
together, and nothing could be handed to somebody else.

## Intended behavior

**A map is one thing**: the picture, the partition cut over it, and the names,
bundled together.

Because the editor lives in the game — see [301](301-the-tracing-mode.md) —
players can build maps, and a map somebody builds is a **mod**. This issue is what
makes one installable.

### What is in it

| | |
| --- | --- |
| the painting | the image the whole thing is played over |
| the network | vertices, edges, places, seeds, names |
| the hierarchy | districts, quadrants, groups, and membership |
| buildings and houses | zones, names, purposes |
| filters | the readings this map declares, and their invented facts — a sun's path, a tree's height |
| events | the hidden things, if any have been written |
| a notice | who made the picture, and under what terms |

That last row is not optional. The board this project develops against is
**somebody else's painting and cannot ship** — see
[the notice](../inspiration-pictures/NOTICE.md) — and a format that makes it easy
to distribute a map without saying where its artwork came from would make that
problem everybody's rather than ours.

### Self-contained, and what that costs

The bundle carries its own image rather than referring to one.

So installing a mod is a single act and a map cannot half-exist. The cost is that
every mod ships a picture, which for something the size of a 25-megapixel
painting is a large download — accepted, because the failure mode of the
alternative is a map arriving without its board and there being nothing sensible
to do about it.

### Loading a bundle must not trust it

A map file is a thing a stranger made. Everything read from one is checked before
use — the validator in [208](208-the-network-validator.md) run in full, indices
in range, the image actually an image of the size it claims.

**Refuse loudly and name what was wrong.** A malformed map that half-loads is
worse than one that does not load, because the person then has a city with quiet
holes in it and no idea why.

## Suggested implementation steps

1. Define the bundle as a directory, and as an archive of that directory — a
   directory so it can be worked on and diffed, an archive so it can be sent.
2. Write the loader and the writer together, with a round-trip test on the
   fixture.
3. Run the full validator on load, before anything is drawn.
4. Refuse on any failure, naming the file, the fault, and where it is.
5. Require the notice to be present and non-empty; refuse to write a bundle
   without one.
6. Report the bundle's size on write, since a person about to distribute
   something ought to know how large it is.

## Related documents and tools

- [The tracing mode](../docs/005-the-tracing-mode.md)
- [The notice on the stand-in board](../inspiration-pictures/NOTICE.md)
