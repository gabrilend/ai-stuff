# 109, 110 — a whole thought on a real ARM machine — info

A complete forward pass, conducted in the second tongue, run on a bare
emulated ARM machine, with every score compared against the first
architecture's as an integer.

## Running it

```
luajit src/110-test-forward-aarch64.lua
```

Takes about a minute and a half, nearly all of it firmware getting to the
payload. The work inside is milliseconds.

## What it exports

`109` builds the payload; `110` drives it.

| Name | Meaning |
|---|---|
| `M.workspace(shape, steps, slot_count)` | where everything writable lives, as offsets from the stack pointer |
| `M.aarch64(options)` | the payload, as assembler text |

## What it proves that the kernel check could not

`100` and `101` showed the ten routines agree with the first architecture one
at a time. This shows they agree **in the order a thought requires** — every
tensor, every layer, every head, and the conducting itself in the same tongue.

Those are different claims. A piece can be right in isolation and be handed the
wrong thing by the piece before it, and nothing about testing pieces separately
would notice. The first architecture learned this the hard way: composing nine
kernels that each passed found a disagreement of four parts in a thousand
million, at the second token only, and the defect turned out to be in the
*reference* rather than the assembly.

It also runs the whole prompt twice more — once with the four-at-a-time matrix
kernel, and once with a conducting bent on purpose.

## Why the answers are carried rather than recomputed

A payload that computed its own expected answers would be comparing an
implementation against itself, which passes whatever it does. The bit patterns
here came off the first architecture's own conducting over the same weights,
and they are compared on the other machine **as integers** — so nothing rounds
during the comparison and "close" cannot happen.

The reference vouches for itself first: before its answer becomes the standard,
it is checked against the recorded fixture. A first architecture that had
quietly regressed would otherwise become the thing the second one is measured
against, and a matching pair of wrong answers reads exactly like a working
port.

## Why the weights are copied as bits

They are read straight out of the packed model as thirty-two bit words and
written into the payload as those same words. No number is turned into text and
back anywhere in the path, so there is no conversion in it to be wrong — which
is the defect `107` exists because of, avoided by not doing the thing.

The payload still refuses to carry a block that is not varied, the same guard
`101` has, for the same reason: a payload was once built holding two hundred
and fifty-six numbers of which three were distinct, and the machine that ran it
did correct arithmetic over wrong data and was very nearly recorded as a broken
port.

## What is reported, and what each number means

| Mark | Meaning |
|---|---|
| `matched` / `of` | scores identical to the first architecture, and scores compared |
| `wide` / `wof` | scores where the two matrix kernels agreed, and compared |
| `got` / `want` | the first disagreement against the first architecture, kept whole |
| `wgot` / `wwant` | the first disagreement between the two matrix kernels |
| `bent` | scores the deliberately wrong conducting moved |

`bent` is the one that must **not** be zero. A zero there means every score
survived a conducting known to be wrong, which would mean the whole payload is
comparing something against itself.

## Where the writable memory is

On the stack, all of it, laid out by `M.workspace` rather than by hand.
Firmware that honours section rights maps the payload's code read-only, so a
buffer in `.text` faults on some machines and not others — a lesson paid for in
`033` and again in `101`.

Everything is cleared before anything reads it. Not tidiness: the first
architecture's buffers come from an allocator that zeroes, so a value read
before it is written would give a zero on that machine and whatever the
firmware left behind on this one. The two would disagree, the port would be
blamed, and the real defect would be somewhere else entirely.

## What it cost to get right

**The stack pointer takes a twelve-bit number, or a twelve-bit number shifted
up by twelve, and nothing in between.** A workspace of seven thousand three
hundred and seventy-six bytes is not a number that instruction can express.
Rounding up to a whole page happens where the size is decided rather than where
it is used.

**A register read before saying something is a register the firmware has
destroyed.** Two of the reported numbers were loaded before their labels were
printed, and the console call — `x9` through `x15` are the caller's to lose —
overwrote them on its way out. The payload then reported what the firmware had
left behind: eight, in the run that found it, with nothing disagreeing at all.
It looked exactly like a real value. The counters survive the same calls only
because `x19` through `x28` are the registers a called routine must give back.

## Result on 2026-08-03

10 of 10. Every one of the 192 scores across four steps matches the first
architecture bit for bit; the two matrix kernels agree on all 192; and the
conducting bent on purpose moved all 192, so the comparison is measuring
something.

## Related

`108-conductor-aarch64` — the conducting this runs.
`099-kernels-aarch64`, `100`, `101` — the ten routines, proved one at a time.
`049`, `050`, `056` — the same claim, on the first architecture.
