# 303 — The page sent back as a living message

phase 3, the relay through rmail

## Current behavior

Pages reach files and HTTP (phase 2). The voices cannot see them.

## Intended behavior

A third publisher in the page keeper's list writes each new page as the body
of `outbox/the-page` in the guide mailbox, under one `to:` line per voice
(temporary name, then rename). Because kuvalu is the author, every edit
travels: rmail carries the newest page to each voice's `inbox/the-page`.
A voice that was offline gets only the newest page when it comes back.

## Suggested implementation steps

1. The publisher, using the page writer (201).
2. Test with the stand-in voices (304): each receives the page, and receives
   edits as the page changes.
3. Count pages handed to rmail in the goodbye receipt.

## Related documents

- `docs/datapath-frame-to-page.md`, step 6
- `docs/rmail-constraints.md`, "A living message"

## Blocked by

201, 301.

## Blocks

304.
