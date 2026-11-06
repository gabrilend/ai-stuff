# 015-history

Replays an org's history and says whether it explains the map.

## What it is for

The claim this project makes is that every change to an organisation is a
diff somebody agreed to. That claim is only worth anything if a change made
any other way is caught. An org that keeps `first.map` keeps a history; this
module starts there, applies every applied proposal in its numbered order, and
judges each as it stood on the day it was applied. The result must be
`org.map` exactly. The rules are H1–H7 in
[how a change is accepted](../docs/003-how-a-change-is-accepted.md#history).
`./replay-history` is the front door.

## Exports

| Function | Returns |
| --- | --- |
| `replay(dir)` | `{ history, steps, matches, final_text, problems, warnings }`; each step is `{ seq, name, date, status, reasons }` |
| `applied_in_order(dir, result)` | the applied proposals in history order, or nil with H2–H4 problems |
| `main(args)` | 0 when the history explains the map or there is none, 1 when not; prints the diff when the map differs |

**A step that was not agreed is reported and the replay continues**, so a
single late approval does not hide a hand edit further on. A step that does
not apply stops the replay, because nothing after it has a map to apply to.
