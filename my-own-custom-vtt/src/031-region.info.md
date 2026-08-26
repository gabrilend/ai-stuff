# 031-region

Named areas, and what it means to be inside one. Regions are what make an
abstract control scope addressable — handing somebody "the tavern" is handing
them a region index.

The geometry itself lives in `029-geometry`. This file is about *which* region.

| Function | In | Out | Notes |
| --- | --- | --- | --- |
| `region_deepest_containing` | world, x, y | region index | **Deepest**, not first. A body in the cellar is in the cellar, not the tavern above it. 0 is open ground. Walks every region. |
| `region_is_within` | world, region, ancestor | 1 / 0 | The permission question. A scope over the forest returns true for the clearing inside it. |
| `region_depth` | world, region | count | Open ground 0, top-level 1. |
| `region_boundary` | world, region | first vertex | Pair it with the region's `vertex_count`. |
| `region_contains` | world, region, x, y | 1 / 0 | One region's polygon only. |

## Deepest wins, and why it has to

A body standing in the cellar is inside both the cellar's polygon and the
tavern's. If the answer were "first found", a scope over the cellar would never
own anything and "when they enter the cellar" would never fire.

Where two regions at the same depth both contain a point — a malformed world the
validator refuses — the lower index wins. Arbitrary, but it must be the *same*
arbitrary on every machine, or two replays of one session diverge.

## An ancestor of zero is the whole map

`region_is_within(w, anything, 0)` is true, including for open ground. That is
how a GM's scope is expressed, and it means the permission check needs no branch
for the GM case.

## The unguarded walk

`region_is_within` runs on every permission check, so it allocates nothing and
walks only the regions block. It has **no cycle guard** — the validator
establishes that no parent chain loops or exceeds `REGION_MAX_DEPTH` (8).

The step bound present in `region_depth` is a different thing: the validator
itself runs against worlds that have not been checked yet, so that one walk must
terminate on a malformed world rather than hang.
