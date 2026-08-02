# 079, 080 — saying how it is — info

Three numbers on a machine that cannot spell: an aspect saying where this
came from, a code meaning whatever the emitting program needs, and a
magnitude on an axis where fifty is ordinary. Issue `207`.

## Running the checks

```
luajit src/080-test-emit-a-status.lua
```

## What `079` exports

| Name | Meaning |
|---|---|
| `COLOURSHAPES` | the seed's own aspects, each a colour AND a shape |
| `new(options)` | lamps, screen, wire — all optional — and where the shared reading lives |
| `emit(status, aspect, code, magnitude, occasion)` | the whole of it |
| `as_text(reading)` | for the wire, and anywhere that can spell |
| `settle(status)` | back to ordinary when a loop that might not have ended, ends |
| `reading(status)` | the machine-wide magnitude as it stands |
| `offer(...)` | `emit`, `aspects`, `how_it_is` as hands |

## Colour and shape, both

Each says the same thing on purpose. Colour alone fails a dim room and a
person who does not distinguish them; shape alone fails a readout that has
only colour. `080` checks that no two aspects share either, since one
encoding failing would otherwise make two aspects the same thing.

## Shown somewhere, or refused

Lamps first, then the framebuffer from `202`, then the serial port — and
**which one took it is reported**. A machine with none of them gets a
refusal rather than a silence, because a status shown nowhere looks exactly
like nothing having happened.

## The meanings are not here

The seed provides the mechanism; the lookup that says what a given code
means is the grown machine's to build, and baking a vocabulary in would
decide something that is not ours to decide. Two machines emitting seventeen
mean unrelated things, and the aspect is what keeps them apart. The
`aspects` hand says so in words, so the machine reading it knows the gap is
deliberate.

Magnitude carries no opinion either: fifty is ordinary, distance in either
direction means attention is warranted, and nothing more. Both ends count —
`080` checks the low crossing as well as the high one, since an axis with
one end is not an axis.

## One dial, shared

The reading lives at one address rather than being a private count per
program, and it is **the same address the assembler's loop emissions push
on** (`073`). So a runaway program and a worried machine appear on one
reading rather than two, which is what makes the picture comparable at all.

Settling returns the magnitude to ordinary but keeps the crossings, because
the thresholds crossed on the way are the record of how close it came.

## Result on 2026-08-02

24 of 24.
