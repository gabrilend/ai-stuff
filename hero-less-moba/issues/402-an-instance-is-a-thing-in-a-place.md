# 402 — An Instance Is a Thing in a Place

| | |
| --- | --- |
| Phase | 4 — The Shared Chest |
| Blocked by | 401 |
| Blocks | 403, 404, 406, 407, 408, 410, 603, 605 |
| Reads | [the shared upgrade pool](../docs/009-the-shared-upgrade-pool.md) |
| Open questions | none |

## Current behavior

There is a catalogue of upgrade kinds and no way for a team to own one.

## Intended behavior

Two records, and keeping them apart is the point of this issue. The **kind** is
the catalogue row from issue 401. The **instance** is a specific thing a specific
team owns, sitting in a specific place:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Index in the team's instance array. |
| `kind` | integer | Catalogue row. |
| `team` | integer | 1 or 2. An instance never changes teams. |
| `slot_kind` | integer | **0** unplaced, 1 lane, 2 lane towers, 3 library. |
| `slot_lane` | integer | 1–3 when `slot_kind` is 1 or 2; **0** otherwise. |
| `locked_by` | integer | Player number, or **0**. |
| `objection_mask` | integer | Bit set of players currently asking for the lock to open. |
| `placed_tick` | integer | When it last arrived somewhere. Drives the UI's recency sort. |
| `is_boon` | integer | 1 if this is a boon. No slot, never dealt out by a surge. |
| `owner` | integer | Player number 1–6, **boons only**. **0** on everything else, which belongs to the team. |
| `moving_to_kind` | integer | Destination slot kind while in transit, or **0**. |
| `moving_to_lane` | integer | Destination lane while in transit, or **0**. |
| `arrives_wave` | integer | The wave id a transit lands with. **0** if not in transit. |

The consequence of the split, and it should be stated in the interface as well as
the code: **there is no such thing as "the team's Sharpened Blades upgrade."** A
team can hold three instances of the same kind and put them in three different
lanes. Duplicates stack. The catalogue is small and fixed; the instance array
grows all match and is never compacted.

The team's view of its own chest is four cached masks, a deck index, and a count:

| Field | Meaning |
| --- | --- |
| `lane_mask[3]` | Bit set per lane, read at spawn. |
| `tower_mask[3]` | Bit set per lane's stone. |
| `library_mask` | Slotted into the library. |
| `base_tower_mask` | The union of all three `tower_mask` entries and `library_mask`. See issue 409. |
| `deck_index` | How far this team has drawn into the shared deck. The gap between the two teams is the whole of the economy's asymmetry. |
| `unplaced_count` | How many instances are doing nothing. Shown large, on purpose. |

The masks are **caches**, rebuilt whenever a placement changes — which is rare —
and read at every spawn — which is constant. Walking the instance array at each
spawn would be the same answer computed hundreds of times more often.

## Suggested implementation steps

1. Write the instance array per team, preallocated generously and grown loudly
   rather than silently if it fills.
2. Write `rebuild_masks(world, team)` and call it from exactly one place, so that
   there is never a path that changes a placement without refreshing the cache.
3. Add an assertion mode that recomputes the masks from scratch and compares, run
   in tests and disabled in release. A stale cache is invisible until it is
   catastrophic.
4. Write the chest into the snapshot so the viewer can show it.
5. Write a test: place, move, and withdraw instances and assert the masks track.

## Related documents and tools

- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md)
