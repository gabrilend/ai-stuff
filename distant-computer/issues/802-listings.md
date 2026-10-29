# 802 — Listings

phase 8, the outward world

## Current behavior

Nothing exists.

## Intended behavior

The steward drafts `listings/<project>.md` for software it judges ready:
what it is, who it is for, the price and how the price was chosen, with
comparable things and where it would be listed. Each listing reaches the
owner as an `outward` request. The owner publishes it, or declines with a
note, and records what was done with `gate note`.

## Suggested implementation steps

1. Listing file format.
2. The readiness check the steward uses: all issues of a phase complete,
   the phase demo runs, the health of the project's tests.
3. The outward request writer.

## Related documents

- `docs/datapath-outward.md`

## Blocked by

801.

## Blocks

804.
