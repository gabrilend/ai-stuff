# 301 — Turn folders and kinds

What a turn is on disk, and the table of turn kinds
([005](../docs/005-datapath-the-hands.md), *the turn kinds*).

## Current Behavior

Nothing starts a model.

## Intended Behavior

- **The kinds table:** one row per kind (`outline`, `describe`, `build`,
  `repair`, `locate`, `amend`), each: the case folders it may read, the case
  folders it may write (both as names resolved against the case, plus
  `source` meaning the case's source path), whether it may read the source,
  its crafts (skill names), and its prompt template.
- **Prompt templates** are text with `{{name}}` slots filled from a table the
  caller passes (the issue id, the issue text, the request text, …). A slot
  with no value refuses: a prompt with a hole is never sent.
- **Make a turn** (case, kind, about, slot values): takes the next turn number
  from the `turns/` folder (four digits, one more than the highest), makes
  `turns/NNNN-kind-about/`, writes `prompt.md` and `confinement.lua` (absolute
  read and write paths). Instructions come from 302.
- The kinds that may read the source are exactly `outline` and `describe`.
  A test holds this: the clean room is a property of the table.

## Suggested Implementation Steps

1. The table and templates. **Test:** every kind's template fills with its
   documented slots; a missing slot refuses.
2. Making a turn folder. **Test:** numbers count up across kinds; the
   confinement file lists absolute paths inside the case (and the source for
   the two kinds that read it).
3. **Test:** no kind but outline and describe has the source in its reads.

## Blocked by

- 105
