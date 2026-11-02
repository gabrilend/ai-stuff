# 117-tag-numbers.lua

The numbers in tags (docs/068, issues 901c, 901d): given by the machine
(the next free number is one more than the highest recorded), recorded
once as a `numbered` ledger line in the case whose parcel first used it,
and a reuse refused, naming that first use. Numbers belong to the whole
project: they are read across every case's ledger.

| Function | In | Out |
|---|---|---|
| `recorded(project)` | the paths table (013) | `{[number] = {case, line, wish}}` for each number's first use, and the highest recorded (0 for none) |
| `next_free(project)` | the paths table | highest recorded + 1 |
| `accept(project, record, p)` | paths; the case the parcel arrived at (lock held); a parcel (079 `read`) | `{tagged = false}` for no tag (nothing recorded); `{tagged = true, number, wish, line}` for a fresh number, now recorded; `nil, finding` for a malformed tag, a number already recorded (naming case and ledger line) or one higher than the next free |
