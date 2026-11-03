# 079-the-shared-frame

The bodies of the viewer's frame in memory another thread can read: a ring of whole frames, never half of one tick and half of the next.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

Issue 709's third part, and its answer to R4. The simulation is to run on a thread of
its own, so that its clock and the drawing's are really separate. What the two share is
**not the live world**: it is the viewer's frame, written whole, tick by tick, into a
ring of blocks in memory both can see. A reader keeps a copy only if the block was
whole before and after it copied — so the screen never shows half of one tick and half
of the next, which is what the snapshot pair was for and still is.

**Nothing in the game uses it yet.** The simulation still ticks on the drawing's
thread. Moving it needs LÖVE's threads and a LÖVE to try them on; the steps are listed
in [709](../issues/709-the-drawn-body-lags-the-real-one.md).

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `settings` | | `slots`, the blocks in a ring: 4, chosen by Claude, open for Ritz. |
| `per_body` | | The per-body arrays of the viewer's frame that cross, in layout order. A new one is a new row here. |
| `bytes(capacity, kinds)` | bodies, upgrade kinds | How much memory a ring needs, to allocate it where both sides can see it. |
| `create(capacity, kinds, memory)` | `memory` optional | A ring, in `memory` if given, else in memory of its own. Errors on a processor other than x86. |
| `adopt(memory)` | a pointer | The same ring, seen from the other side, from the pointer alone. Errors on memory with no ring header. |
| `write(ring, frame)` | a stamped viewer frame | — Its bodies into the next block, whole. Never waits. |
| `reader(ring)` | | A reader: its own `newest` and `previous` frames, shaped like the viewer's, and a count of `torn` copies thrown away. |
| `read(ring, reader)` | | Whether the newest moved. Brings `newest` to the newest whole tick and `previous` to the tick before it, or to the newest again when that is gone. |

## Data structures it owns

One block of doubles. The ring's header: capacity, kinds, slots, the last slot written.
Then each block: its sequence number, tick, live count, fading count and zone count; one
array per `per_body` field; one array per upgrade kind; the live list; the fading list.
Every array is `capacity` long and indexed by soldier id, like the frame it copies.

## The rule for reading it

A block's sequence number is odd while it is being written and even when it is whole.
A reader notes it, copies, and notes it again; if it was odd or has changed, the copy is
thrown away. The functions that touch a sequence number are never compiled, so the
loads and stores around a copy happen in the order written, and x86 keeps them in that
order. Other processors would need fences, so `create` refuses them.

## Tested

[080](../tests/080-the-shared-frame.lua), with two real processes sharing one mapping:
a match written tick by tick while the other side reads, every kept frame compared with
the match played again; and a writer lapping a two-block ring, where every torn copy
must be thrown away. Both fail if the second look at the sequence number is removed.
