# 816 — A Minted Axis Needs a Colour and an Angle

| | |
| --- | --- |
| Phase | 8 — The Scaffold |
| Blocked by | 501, 808 |
| Blocks | 910 |
| Reads | [filters and the weave](../docs/006-filters-and-the-weave.md), [the scaffold](../docs/009-the-scaffold.md) |
| Open questions | — |

## Current behavior

Axes are minted with a name. A filter needs a name, a colour, an angle and a mode,
so a minted axis cannot be drawn.

## Intended behavior

**An axis and a filter are the same record**, so every axis the city grows must
arrive fully formed enough to be hatched across the map.

| Field | Where it comes from |
| --- | --- |
| `name` | generated at the moment of mixing — see [815](815-forcing-a-closed-thing-open.md) |
| `colour` | **assigned here** |
| `angle` | **assigned here** |
| `mode` | interwoven, unless something says otherwise |
| `reading` | the axis value, per actor |

### The colour rule makes this harder than it looks

[What this game is](../docs/001-what-this-game-is.md) requires that **colour never
carries a fact the words don't also carry**, and that a filter be identifiable by
colour *and* angle *and* name — three redundant channels for one identity.

So an assignment scheme cannot simply cycle through a palette. Two axes that are
about related things and end up adjacent in colour and angle would read as
variations of each other when they are not.

### The number of axes is unbounded, which rules out a table

There is no fixed catalogue, so colours and angles cannot be authored per axis. The
assignment has to be a **function of the axis**, computed once when it is minted
and then held forever — an axis whose colour changed between sessions would make
the map unreadable in a way nobody could name.

**Working approach:** derive both from the axis name, so the same name always gets
the same appearance, and check the result against every axis already in play for
adequate separation in colour and in angle before accepting it.

### The weave is what makes an unbounded set survivable

[Filters and the weave](../docs/006-filters-and-the-weave.md) already answers the
question this would otherwise raise. Flat stacking goes to mud at three filters;
weaving degrades gracefully because every filter gets an equal share of the
crossings and none is ever wholly hidden.

Answer A9's ruling that any number of filters may be active at once was made for
its own reasons and turns out to be what lets the filter list grow forever.

## Suggested implementation steps

1. Assign colour and angle when an axis is minted, deriving both from its name so
   the mapping is stable across runs.
2. Check separation against the axes already in play, in colour and in angle
   independently, and re-derive if too close.
3. Store the assignment with the axis. Never recompute it from a palette position,
   which would shift when another axis is minted.
4. Default the mode to interwoven, so a new axis joins the weave rather than
   painting flat over everything.
5. Report the full set of axes with their colours and angles, so the separation can
   be inspected rather than assumed.
6. Test that minting the same name twice yields the same colour and angle, and that
   no two live axes fall within the separation threshold.

## Related documents and tools

- [Filters and the weave](../docs/006-filters-and-the-weave.md) — the record, the weave, and the three modes
- [501 — what a filter is](501-what-a-filter-is.md)
- [What this game is](../docs/001-what-this-game-is.md) — the colour rule
