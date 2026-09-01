# 504 — The Three Modes, and the Order

| | |
| --- | --- |
| Phase | 5 — Filters and the Weave |
| Blocked by | 501 |
| Blocks | 505 |
| Reads | [filters and the weave](../docs/006-filters-and-the-weave.md) |
| Open questions | — |

## Current behavior

Filters exist. Nothing decides what happens when more than one is on.

## Intended behavior

**Any number of filters may be active at once.** Each sits in one of three places:

| Mode | Behaviour |
| --- | --- |
| **behind-always** | painted flat, beneath everything else, in the order added |
| **interwoven** | joins the weave with every other interwoven filter |
| **top-always** | painted flat, over everything else |

The two *always* modes do not weave with anything, including each other. They are
simply painted. **Only the interwoven set weaves, and it weaves as a whole** — see
[505](505-the-weave.md).

### The full render order, every frame

1. the painting
2. **behind-always** filters, painted flat in order
3. **the interwoven set**, resolved together in one pass
4. **top-always** filters, painted flat in order
5. the cage — [207](207-the-cage-shows-one-level.md)
6. the glow — [507](507-the-glow.md)

The painting is never dimmed and never tinted. Hatching leaves gaps and the
painting shows through them; that is the whole mechanism by which several filters
and a painting share one surface.

### Why the modes exist at all

Because not everything wants to be woven. A filter marking something you must not
miss belongs on top, unconditionally. A filter providing background context — a
wash of terrain, say — belongs underneath where it will not compete. The weave is
for the ones you are actively comparing.

Giving the choice to the person rather than fixing it means the same filter can be
background in one investigation and foreground in the next.

### Mode is per-filter and changed at runtime

From the tome's chip controls — see [603](603-the-focused-filters-controls.md).
Changing it must take effect immediately, which means the render pass groups by
mode each frame rather than caching a grouping.

## Suggested implementation steps

1. Add mode to the filter record, defaulting to interwoven.
2. Group active filters into three lists each frame.
3. Render the three groups in order, with the interwoven group handed to the weave
   as a set rather than looped over.
4. Keep flat painting genuinely flat — no blending trickery that makes a
   top-always filter partly transparent to the one below, which would be weaving
   badly rather than painting.
5. Test that moving a filter between modes changes only its position in the order
   and nothing about its own appearance.

## Related documents and tools

- [Filters and the weave](../docs/006-filters-and-the-weave.md)
- [The map surface](../docs/002-the-map-surface.md)
