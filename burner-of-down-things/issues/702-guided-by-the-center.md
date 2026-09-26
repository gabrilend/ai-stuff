# 702 — Guided by the center

Letting the center decide order, and telling every turn what it says
([009](../docs/009-datapath-the-center.md)).

## Current Behavior

The center can be computed; nothing uses it.

## Intended Behavior

- Waiting requests (603) are ordered by the weight of the request plus the
  weights of the issues it touched (if graded), heaviest first; ties by age.
- Within a wave (503), issues are started heaviest first; ties by id. (With
  a pool smaller than the wave, this decides which start first.)
- Every turn's instructions (302) get the paragraph: the five heaviest
  things, named in words — "lately the person has asked about …, and the
  build of … has been failing" — or that nothing has been asked yet.

## Suggested Implementation Steps

1. **Test:** two requests, the newer touching a heavy issue: it goes first.
2. **Test:** a turn's `instructions.md` contains the paragraph with the
   heaviest id.

## Blocked by

- 701
- 603
