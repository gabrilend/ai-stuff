# 103 — Dates

Every note is stamped with the day it was written.

## Current Behavior

Nothing is built yet.

## Intended Behavior

A module `src/dates.lua` returning a table with two functions.

| Function | In | Out |
|---|---|---|
| today() | nothing | the local date as `YYYY-MM-DD` |
| is_date(text) | a string | true when it is exactly four digits, dash, two digits, dash, two digits |

## Suggested Implementation Steps

1. today and is_date. Test: today() passes is_date; "2026-9-1" does not.

## Acceptance

```sh
luajit tests/103-dates.lua
```

## Blocked by

None

## Covers

- src/dates.lua
