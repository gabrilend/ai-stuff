# 091-put-it-on-a-card — info

The image reaches a physical medium. Issue 503, and the only operation in this project that cannot be undone by writing more software.

Everything else here can be fixed by building it again. This one writes over whatever was on somebody's disk, and if it is the wrong disk that data is gone. So the confirmation is uncomfortable on purpose, and the discomfort is a feature rather than an oversight.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `091-put-it-on-a-card.lua` and run the sweep again.*

## Invocation

```
luajit 091-put-it-on-a-card.lua --image FILE --to DEVICE --size BYTES
[--to DEVICE --size BYTES ...]
[--i-know] [--dry-run]
```

## What it offers

| | What it is |
|---|---|
| `M.WHAT_IT_ASKS` | the confirmation, and why it is shaped like this |
| `M.look(where)` | What is actually at a path, so the operator's claim can be checked against the machine's own account rather than trusted. |
| `M.check(target, image_bytes, found)` | Everything that must be true before anything is written. |
| `M.write(target, image, options)` | Write, read back, compare, report. |
| `M.run(options)` | The whole thing, over however many cards were named. |
| `M.say_what_happened(results)` |  |

### In more detail

**`M.look(where)`**

What is actually at a path, so the operator's claim can be checked against
the machine's own account rather than trusted.

**`M.check(target, image_bytes, found)`**

Everything that must be true before anything is written. Returns true, or
nil and every reason -- all of them, because an operator about to do
something irreversible should see the whole objection rather than fix one
thing at a time and try again.

**`M.run(options)`**

The whole thing, over however many cards were named. One image is meant to
serve many machines, and doing them one at a time is where mistakes come
from.

## The operator names the device and something about it

Not just the path -- device paths move between one boot and the next, and the disk that was the second one yesterday may be somebody's photographs today. Naming the size or the serial as well means a mistake has to be made twice, identically, to get through.

## Read-only media are preferred

and this says so where an operator will see it. A seed nothing can write to can be carried from machine to machine indefinitely, plants the same thing every time, and cannot be damaged by a computer dying halfway through being started (docs/003).

## Worth knowing

WRITTEN, THEN READ BACK, THEN COMPARED. Against the identity the builder produced (502), and the comparison is REPORTED rather than assumed. A flasher that says "done" without reading anything back has told you that it finished, which is a different fact from the card being right.

## Where it sits

**Belongs to** `503`.

**Checked by** `090-test-the-image`.

