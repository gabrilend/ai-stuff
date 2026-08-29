# 510 — Switching Person Repaints

| | |
| --- | --- |
| Phase | 5 — Filters and the Weave |
| Blocked by | 502 |
| Blocks | 607 |
| Reads | [filters and the weave](../docs/006-filters-and-the-weave.md) |
| Open questions | — |

## Current behavior

Readings take a person. Only one person is ever passed.

## Intended behavior

Taking up a different person **repaints the entire map**, and does so without any
code written for the purpose.

| What changes | Because |
| --- | --- |
| the hatching | every reading is theirs — [502](502-a-reading-takes-a-person.md) |
| where the map is blank | ignorance is a reading of nothing, and theirs is elsewhere |
| which time-curves can be read | you can only model people they know — [707](707-curves-you-are-allowed-to-read.md) |
| which buttons are lit | what they can do differs from what somebody else can |
| where you are | the whereabouts equation is theirs — [703](703-whereabouts-is-a-function.md) |

### How you take up a person

By descending: block, building, house, the people in it. Then choosing one. See
[607](607-descending-to-a-person.md). No building footprints, no new marks on the
map, and it is how a Paradox game does it too — a list, not a pixel.

### What must not happen

**The view must not move.** Switching person changes whose city you are looking
at, not where you are looking. Pan, zoom and selection stay exactly as they were,
so the change is legible as a change — the same streets, differently known.

If the camera jumped to the new person's home, the repaint would be lost in the
motion and the whole point of the feature would be invisible.

### What it is for

Not convenience. It is the only way to **look directly at somebody else's
ignorance**, which for a game about a city that constrains what people may know is
close to the subject itself.

A servant in the eastern mansions has a blank harbour. A bargeman has a bright
river and a dark walled quarter. Switching between them, without the view moving,
shows you the shape of a life as a change in what is lit.

### Cost

Every cached reading is invalidated at once, so the frame after a switch does the
full evaluation again. That is a few thousand readings, which is affordable, and
the alternative — caching per person — is worth doing only if measurement says so.

## Suggested implementation steps

1. Hold the current person in one place, near the top of the frame, and pass it
   down. No global reachable from anywhere.
2. On switch, invalidate reading caches and nothing else — not the view, not the
   selection, not the identity buffer, which are all about *where* rather than
   *whose*.
3. Show plainly in the tome whose model is on screen, at all times, since the map
   itself carries no text and a person could otherwise forget.
4. Cross-fade the hatching over a short interval so the change reads as a change
   rather than a flicker.
5. Test that switching alters hatching and leaves pan, zoom and selection
   identical.

## Related documents and tools

- [Filters and the weave](../docs/006-filters-and-the-weave.md)
- [What this game is](../docs/001-what-this-game-is.md)
