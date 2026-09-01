# 406 — Two Bodies Idling Together

| | |
| --- | --- |
| Phase | 4 — The Wandering |
| Blocked by | 404, 405 |
| Blocks | nothing |
| Reads | [idling and being idle together](../docs/015-idling-and-being-idle-together.md) |
| Open questions | none |

## Current behavior

Bodies idle alone, near each other, unaware.

## Intended behavior

Two idling bodies in adjacent cells, both idle longer than `notice_seconds`, may
enter a **shared idle**: both given the same idle row, the same clock, and each
set to face the other.

That is the entire mechanism, and it is enough to produce something that reads as
two people having a conversation. **Nobody is having a conversation.** There is
no dialogue, no relationship, and no memory of it afterwards. There are two
timers set to the same value and two `facing` fields pointed at each other. This
is worth stating plainly, because the temptation to add the relationship
afterwards is strong and it would be a great deal of machinery for something the
timers already deliver.

Entered through [the meet pass](405-the-meet-pass-pairs-bodies.md) and never by
either body deciding alone — two bodies each independently deciding to share
produces the case where one shares and the other has already walked off, leaving
a body doing a synchronised animation at an empty cell. Funny once, then a bug.

Cancelling a shared idle cancels it for **both**. A body left in one whose
partner has gone is the same empty-cell case from the other direction, and the
generation check is what catches it: a shared idle whose partner fails validation
ends the same tick.

## Suggested implementation steps

1. Add the little-guy-to-little-guy entry to the meet table.
2. Write the willingness test: both idle, both past `notice_seconds`, neither
   already partnered.
3. Set both bodies' idle row, clock, partner and partner generation, and point
   their facings at each other.
4. Write the cancel that releases both, and call it from the generation check in
   the decide pass.
5. Test: a shared idle ends for both when either is killed. Over a long run no
   body is ever in a shared idle whose partner is not in one with it.

## Related documents and tools

- [Idling and being idle together](../docs/015-idling-and-being-idle-together.md)
