# 801 — Funding goals

phase 8, the outward world

## Current behavior

Nothing exists.

## Intended behavior

`goals/<name>.md` files (`docs/datapath-outward.md`, "Funding goals"),
written by the steward on `distant-work` and reaching kuvalu as `commit`
requests. A goal's progress is never typed in by hand. It is computed from
the near ledger's `applied` entries for outward requests that name the goal,
with an `amount` field. The first goal, from the vision: hire a person to
handle legal and business paperwork and answer outward requests.

When progress meets `needs`, the steward files one `decision` request.

## Suggested implementation steps

1. Goal file format and reader.
2. Progress from the ledger.
3. The first goal file.

## Related documents

- `docs/datapath-outward.md`

## Blocked by

102, 603.

## Blocks

802, 803, 804.
