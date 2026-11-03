# 080-the-shared-frame

The shared frame, read by another process while a real match is being written into it.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

The one claim [the shared frame](../src/079-the-shared-frame.info.md) makes: a reader
never keeps half of one tick and half of the next. One process cannot test that,
because nothing changes under a copy in progress, so this file forks. It runs on its
own in `./run-tests code`, so that a failure points here.

## Exports

None. Run with `luajit tests/080-the-shared-frame.lua`; exits non-zero on a failure.

## Data structures it owns

None beyond each test's own world and shared mapping.

## The checks

| Check | Fails when |
| --- | --- |
| A frame written is read back exactly; nothing new reads as nothing new | …a field is dropped or misplaced on the way across. |
| The next tick makes an adjacent pair; a reader that fell behind still gets one | …the blend is handed two ticks that were never neighbours. |
| A block being written is never read; with no whole pair, the previous is the newest again | …a half-written block is drawn. |
| A ring is adopted from its pointer alone; memory that is not a ring is refused | …the other thread cannot find the layout, or reads garbage as a ring. |
| **Two processes**: a match written while read; every kept frame is exactly the frame the same match had at that tick | …a torn frame was ever kept. |
| **A writer lapping the reader** in a two-block ring: torn copies happen and every one is thrown away | …the second look at the sequence number is missing. Both two-process checks fail then. |
