# 901 — Tags and parcels

What arrives at the switchboard, and how it asks ([068](../docs/068-datapath-the-switchboard.md)).

## Current Behavior

Nothing is handed to the machine but whole sources and change requests.

## Intended Behavior

- A **parcel** is one or more files dropped in a switchboard folder.
- A **tag** is a first line `language model prompt <number>: <what is wanted>`. Numbers are given by the machine (the next free one), and each is recorded in the ledger once; a parcel reusing a number is refused, naming the first use.
- Parcels with no tag are still accepted: the router works out what they are from their contents alone.

## Suggested Implementation Steps

1. Reading a tag. **Test:** the number and the wish are read; a malformed tag is a finding that shows the right form.
2. Numbers. **Test:** the next number is one more than the highest recorded; a reused number is refused.

## Blocked by

- 104
