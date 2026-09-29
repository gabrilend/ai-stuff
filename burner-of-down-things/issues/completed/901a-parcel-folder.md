# 901a — The parcel folder

The first piece of 901.

## Current Behavior

Built. `src/079-the-parcel.lua`'s `read(folder)` reads every file in a
switchboard folder as one parcel, `{folder, files}`; an empty or missing
folder reads as `nil` (nothing arrived), not an error. Checked by
`tests/080-checking-the-parcel.lua`.

## Intended Behavior

A **parcel** is one or more files dropped in a switchboard folder; reading
a parcel means reading every file currently in that folder as one unit.

## Suggested Implementation Steps

1. The switchboard folder path (case-relative, alongside `turns/`).
   Deferred: 901a's own test uses a scratch folder directly; wiring the
   real case-relative path in is 901b's concern once tags are read from it.
2. A parcel-read function returning `{files = {...}}`. Done: `079-the-
   parcel.lua`'s `read`. **Test:** a folder with three files reads as one
   parcel of three; an empty folder reads as no parcel, not an error. Done.

## Blocked by

- 104
