# 901c — Number issuance

The third piece of 901.

## Current Behavior

Built. `src/117-tag-numbers.lua`'s `recorded(project)` reads every
case's ledger for `numbered` lines (a new ledger kind, docs/003 and 016's
`KINDS`) and returns each number's first use and the highest recorded;
`next_free(project)` is one more than that, 1 when nothing is recorded.
`machine number` (`118-the-switchboard-commands.lua`, docs/012) prints
the tag with the next free number, recording nothing. Checked by
`tests/119-checking-number-issuance.lua`.

Decisions: numbers belong to the whole project, not to one case, so
"prompt 7" means one thing wherever it turns up — the highest is read
across every case's ledger. A number is recorded where a parcel first
uses it (901d), not when it is handed out: handing one out writes
nothing, so asking twice gives the same number until it is used.

## Intended Behavior

Numbers are given by the machine, always one more than the highest
recorded in the ledger — never chosen by whoever writes the tag.

## Suggested Implementation Steps

1. A "highest recorded number" reader over the ledger (016's `read`).
2. The next-number function. **Test:** the next number is one more than
   the highest recorded; an empty ledger's next number is 1. Done: `117-tag-numbers.lua`'s
   `recorded` and `next_free`.

## Blocked by

- 901b
