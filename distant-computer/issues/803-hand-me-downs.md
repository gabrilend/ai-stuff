# 803 — Hand-me-downs

phase 8, the outward world

## Current behavior

Nothing exists.

## Intended behavior

"I just reached level 16, who wants my old two handed sword?" When the
steward replaces one of its own tools or libraries with a better one, it
writes `hand-me-downs/<name>.md`: what it is, what replaced it and why, what
it still does well, and who might want it and why them (the merit). Inside
the monorepo, a hand-me-down to another project is a `commit` request. To
anyone outside, it is an `outward` request.

## Suggested implementation steps

1. File format.
2. The steward's prompt (601) gains: "when you replace something, write its
   hand-me-down".
3. The request writer for each case.

## Related documents

- `docs/datapath-outward.md`

## Blocked by

801.

## Blocks

804.
