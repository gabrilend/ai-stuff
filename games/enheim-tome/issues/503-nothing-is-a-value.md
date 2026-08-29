# 503 — Nothing Is a Value

| | |
| --- | --- |
| Phase | 5 — Filters and the Weave |
| Blocked by | 501, 502 |
| Blocks | 505, 804 |
| Reads | [filters and the weave](../docs/006-filters-and-the-weave.md) |
| Open questions | — |

## Current behavior

A reading returns a number.

## Intended behavior

A reading may return **nothing at all**, and that is different from returning
zero.

| Answer | Meaning | How it draws |
| --- | --- | --- |
| `0` | this person knows the fire risk here is low | widest hatching |
| `1` | this person knows it is high | tightest hatching |
| **nothing** | **this person has no idea** | **bare painting** |

### The subsystem this deletes

There is no fog of war to build. No discovery flags, no confidence channel, no
greyed-out unknown state, no second colour meaning "unsurveyed".

Look at the city under any filter and the hatched parts are that person's
knowledge, the bare parts their blindness, and **the picture is most beautiful
exactly where they are ignorant**. The painting shows through where nothing is
known, which is both the correct behaviour and the prettiest one.

This is worth recording as a pattern rather than a detail: before adding a channel
to say *we don't know*, check whether the existing channel can simply decline to
answer.

### For knowledge filters it is not even a special case

A person's knowledge **is** the set of events they hold — see
[803](803-knowledge-is-held-events.md). So a filter asking "what do you know of
hidden things here" returns nothing for a place where they hold none, without any
code deciding to.

The two systems are one system. Nothing bridges them because there is nothing to
bridge.

### The discipline

Nothing must be genuinely distinct from zero all the way down — in the reading, in
whatever caches it, and in the shading. The classic failure is a cache
initialised to zero, after which every unvisited place quietly reports *known to
be low* instead of *unknown*, and the map lies in a way that looks completely
plausible.

## Suggested implementation steps

1. Represent absence distinctly from zero in the reading's return, and in any
   table that holds results.
2. Never initialise a reading cache to zero. Initialise to absent, or do not
   pre-fill it.
3. Have the shading skip a place entirely when the answer is absent — no hatching
   drawn, not hatching drawn at zero density.
4. Test the difference explicitly: a fixture with one place known-to-be-zero and
   one unknown must render differently, and a test must assert that rather than
   leaving it to the eye.

## Related documents and tools

- [Filters and the weave](../docs/006-filters-and-the-weave.md)
- [Events and what people know](../docs/009-events-and-what-people-know.md)
