# 901 — Tags and parcels

What arrives at the switchboard, and how it asks ([068](../docs/068-datapath-the-switchboard.md)).

## Current Behavior

Built, in four pieces (issues/completed/901a-901d): a folder of files
reads as one parcel (`079-the-parcel.lua`'s `read`); its first line reads
as a well-formed tag's number and wish, no tag at all, or a malformed
finding naming the right form (`tag`); numbers are given by the machine,
one more than the highest recorded across every case's ledger
(`117-tag-numbers.lua`'s `next_free`, `machine number`); and a parcel's
fresh number is recorded once as a `numbered` ledger line, while a reused
one is refused, naming its first use (`accept`). Both of this issue's
tests hold: `tests/101-checking-tag-parsing.lua`,
`tests/119-checking-number-issuance.lua`,
`tests/120-checking-reuse-refusal.lua`.

## Intended Behavior

- A **parcel** is one or more files dropped in a switchboard folder.
- A **tag** is a first line `language model prompt <number>: <what is wanted>`. Numbers are given by the machine (the next free one), and each is recorded in the ledger once; a parcel reusing a number is refused, naming the first use.
- Parcels with no tag are still accepted: the router works out what they are from their contents alone.

## Suggested Implementation Steps

1. Reading a tag. **Test:** the number and the wish are read; a malformed tag is a finding that shows the right form.
2. Numbers. **Test:** the next number is one more than the highest recorded; a reused number is refused.

## Sub-issues

- 901a — the parcel folder
- 901b — tag parsing
- 901c — number issuance
- 901d — reuse refusal

## Blocked by

- 104
