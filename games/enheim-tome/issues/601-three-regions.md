# 601 — Three Regions

| | |
| --- | --- |
| Phase | 6 — The Tome |
| Blocked by | 103 |
| Blocks | 602, 604, 606 |
| Reads | [the tome](../docs/007-the-tome.md) |
| Open questions | — |

## Current behavior

The tome pane exists and is empty.

## Intended behavior

Three regions, stacked, with fixed responsibilities.

```
┌─────────────────────┐
│  the hour  ───●───  │  ┐
│  ● ● ● ● ● ● ● ●    │  │ welded — map controls
│  ─────────────────  │  │ and the search when typing
│  shade              │  │
│  angle   ◜   47°    │  │
│  mode    [inter ▾]  │  ┘
├─────────────────────┤
│   ▣  ▣  ▣  ▣  ▣     │  ┐ welded — fixed positions
│   ▣  ▣  ▣  ▣  [GO]  │  ┘ learned by hand
├─────────────────────┤
│  Tanner's Row       │  ┐
│  forty-one souls    │  │ scrolls
│  nine households    │  ┘
└─────────────────────┘
```

| Region | Behaviour | Holds |
| --- | --- | --- |
| **top** | welded, fixed height | the hour; the filter chips; the focused filter's controls; the search field while typing |
| **middle** | welded, fixed positions | the icon buttons, the move queue, and go |
| **bottom** | scrolls | text on a dark ground, coloured words |

### The principle that puts the map controls at the top

**Controls sit closest to the thing they control.** The map is to the left of the
tome, and the top of the tome is the part your eye reaches when coming off the
map. So the hour and the filters live there, and nothing else competes for that
position.

### Why two welded regions and not three, or one

The top and middle are welded because their contents must be **findable without
looking** — a filter angle you are adjusting, a button you press twenty times an
hour. Anything that can scroll away from under your hand is something you have to
hunt for.

The bottom scrolls because text is unbounded and cannot be welded to anything.

### The heights

The welded regions must not grow without bound, which is a real risk for the top
since any number of filters can be active. That is solved by chips —
[602](602-the-chip-row.md) — and it is why the top holds chips plus **one**
filter's controls rather than every filter's.

Heights come from `input/what-to-start-with`.

### Selection drives the scroll

When a place is selected, the scrolling region returns to its top rather than
staying wherever it was. Otherwise selecting a new block leaves you halfway down
the previous one's text, which reads as the interface having failed to notice.

## Suggested implementation steps

1. Compute three rectangles from the tome rectangle and the two welded heights.
2. Clip each region so none can draw into another.
3. Give the bottom a scroll offset, clamped to its content, with the wheel bound
   only when the pointer is over it.
4. Reset the scroll on selection change.
5. Test that content longer than the pane scrolls, that the welded regions never
   move, and that a very long filter name cannot push the button pane down.

## Related documents and tools

- [The tome](../docs/007-the-tome.md)
