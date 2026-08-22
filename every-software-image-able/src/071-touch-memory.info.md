# 071, 072 — touching memory — info

Reading and writing physical addresses, as hands the machine can ask for.
No translation and no permission layer — this machine has neither, and
adding one here would be inventing a kernel the design deliberately does not
have. Issue `203`.

## Running the checks

```
luajit src/072-test-touch-memory.lua
```

## What `071` exports

| Name | Meaning |
|---|---|
| `new(options)` | usable ranges, the ranges we are made of, and the real read/write |
| `check_read`, `check_write` | whether one touch may happen, and why not |
| `check_range_read`, `check_range_write` | the same for a stretch |
| `peek`, `poke` | one touch; `poke` returns what the address holds afterwards |
| `fill`, `copy`, `compare` | the bulk forms |
| `offer(catalogue, hands, memory)` | all of it as hands, plus `memory` to ask what may be touched |

The real read and write are handed in, because on the metal they are three
instructions and hosted they are a pretend region. The rules are the same
either way, and the rules are what this file is.

## The one refusal

**No longer true as of 2026-08-21, kept here because the reasoning is.** Writes
into the engine and the weights used to be refused — the only place in the
seed where the model is stopped from doing what it asked. The reason is
specific rather than protective: a mind that overwrites itself does not
report an error, it goes quiet. Every other mistake here is recoverable by
writing more software.

Reads are allowed everywhere the map calls usable, **including its own
mind**. A machine reading itself is doing something useful, and `204` depends
on reading back what it placed.

**What happens now:** the write lands, and the hand returns a third value — a
warning naming what was written over and telling the machine to read itself back
from the copy on disk if this was not deliberate. `memory.warnings` counts them
and `memory.last_warning` holds the most recent. The tool-call reply carries the
number on the first line and the warning on the second.

The reason for the change is that the only things worth restricting are the ones
that damage hardware, and a machine is entitled to do something stupid to itself.
The reason for the warning is the same reason the refusal existed: a damaged mind
cannot notice it is damaged, and a machine that cannot notice cannot decide to
reload. Saying so takes nothing away.

Formerly: a write that only clipped the protected range was refused too, and a
bulk write that would reach it was refused **before any of it happens** rather
than
halfway through.

## What is returned is what is there

`poke` writes and then reads back, and hands back what the address actually
holds — not what was written. Some addresses are devices and do not keep what
was put in them; that difference is the most interesting thing the bus can
say, and smoothing it over would hide it. The test includes a pretend device
that always reads back the same pattern, for exactly this reason.

## A byte count is not a width

The bulk forms have their own range checks. Running them through the
single-touch width check refused every bulk operation as though sixty-four
were an impossible width — correctly, for entirely the wrong reason. It went
unnoticed because the comparison that should have caught it was itself being
refused, and the test could not tell a refusal from a match.

So `compare` now answers three ways: an offset when the ranges differ,
**false** when they are identical, and nil with a reason when it could not
look. *They are the same* and *I could not see* are different facts.

## Unaligned touches are refused

Some processors fault on one and some quietly split it into two, which is a
different operation than the one asked for. Refusing is the only answer that
means the same thing on every machine.

## What it cannot cover

A read that never returns. Some real buses hang on an address nothing
answers, and no rule here prevents that — only the map can, and the map is
the firmware's word rather than a fact.

## Result on 2026-08-02

22 of 22.
