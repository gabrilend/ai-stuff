# 310 — The launch box library

## Current behavior

**The box library is the eight boxes phase 2 wrote to exercise the
engine with.**

Enough to prove nothing is lost and to measure how much a run costs.
Not enough to write a program anybody wants.

## Intended behavior

**The boxes every later phase assumes exist.**

| box | takes | gives back | what it is |
|---|---|---|---|
| `say` | a value | nothing | writes it down the serial line to the laptop |
| `clock` | a trigger | the current count | reads the chip's timer, inside the box |
| `random-byte` | a trigger | one byte | reads the chip's generator, inside the box |
| `refuse` | a value | nothing | always refuses, so 214's removal path has something to prove itself against |
| `stop-everything` | a value | nothing | panics on purpose, so the panic path has the same |
| `recalibrate` | a value and a range | a new range | half of what used to be the seventh routing kind (308) |
| `shape` | a value and a range | the shaped value | the other half |

### A source is a box with a trigger

This is the mechanical point worth writing down, because it is not
obvious and everything above depends on it.

A station runs when every one of its inputs holds a value. A box with
*no* parameters therefore has no inputs, is always ready — and can never
be made to run, because there is no port for anybody to write to.

```
   ✗   ┌────────────┐            nothing can ever start this.
       │  the time  │ ─→ out     no ports, so no writes,
       └────────────┘            so no readiness check ever runs.

   ✓   ┌────────────┐            a write to the trigger runs it.
   ──→ │  the time  │ ─→ out     the value written is ignored;
  trig └────────────┘            the writing is the point.
```

So every source takes one input it does not use. Writing that port is
what asks for a reading. It is the same mechanism as everything else —
writing a fixed value runs the readiness check on its station — and it
means "give me the time now" is an ordinary arrow rather than a special
case in the engine.

**Which is also why a value is never fresh at the instant it is used.**
A reading is taken when the trigger arrives and travels like any other
value. A box that genuinely needs the current time asks for it *inside
itself*, which is exactly what `clock` does and why it is a box rather
than a wire.

### There is no timer box

The old library had one: a station that armed itself and fired every
so often, which the cycle detector had to be taught about.

There is nothing to build. When every core has run out of work, the
idle path already arms the chip's timer and parks (phase 2's 206). The
core wakes at the deadline and writes a fixed-value port — which runs
the readiness check, which builds a task, which is the whole of what a
timer was for.

A tick is the engine waking up. It does not need a box and it does not
need a routing kind, and the sixty-times-a-second map that phase 5
hangs every input surface off is an ordinary map fed by an ordinary
write.

## Suggested implementation steps

1. Each box as an ordinary box source, so the generator picks them up
   with everything else — there is no privileged library.
2. `say` over the existing serial channel. It returns nothing, so it is
   a sink and delivery skips it entirely.
3. `clock` and `random-byte` reading their registers directly, with a
   comment at each saying why reading inside the box is the point.
4. The two calibration boxes, wired as 308's worked example, kept
   together in one source file so the pair reads as a pair.
5. The two deliberate-failure boxes, each with a one-station map that
   exercises its path end to end.
6. Delete the timer from the plan and write the paragraph above where
   somebody would look for it.

## Open questions

- *Does `say` need to say what it is saying about?* A bare value down
  the serial line with no label is nearly useless once three stations
  are using it. Either it takes a second input for the label — one more
  wire on every use — or the engine tells it which station it is, which
  means a box learning something about its own placement, which nothing
  else in the design does. Worth resolving deliberately; leaning toward
  the second input.
- *Is `random-byte` the right width?* A byte at a time is fine for
  choosing among a few exits and terrible for anything that wants a
  number. Probably wants to be the chip's natural width, with narrowing
  left to whoever needs it.
- *What does `refuse` refuse about?* 214 gives a box a way to say "not
  this value". Whether that carries a reason a person can read, or only
  a kind, decides what the error slot can hold. This box is the first
  caller and therefore the one that settles it.

## Blocked by

301, 302, 308.

## Blocks

312, and phase 5's input maps.

## Related

- [212 — Maps built by hand](212-maps-built-by-hand.md), the starter set
  this extends
- [206 — Sleeping and waking](206-sleeping-and-waking.md), which is the
  timer
- [214 — When a box removes itself](214-when-a-box-removes-itself.md),
  which two of these exist to test
