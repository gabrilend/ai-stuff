# 308 — The kinds that pick an exit

## Current behavior

**Every station has one exit and sends everything down it.**

Phase 2's delivery walk chooses an exit through a table with one row
filled in, deliberately, so that adding the rest is adding rows.

## Intended behavior

**A station's kind is consulted at exactly one moment — choosing an
exit on the way out — and nowhere else.**

That is the property worth protecting. A new kind is a row in one
table, never a new branch in several functions that have to be kept
agreeing with each other.

| kind | exits | how one is chosen | what it needs |
|---|---|---|---|
| **plain** | 1 | there is only one | nothing |
| **comparator** | 3 | ask the type's ordering how the value compares to the threshold | a threshold port, and an ordering (303) |
| **iterator** | N | the station's cursor, one further each time | a cursor on the station |
| **random** | N | a number from the chip's own generator | nothing |
| **weighted** | N | that same number against cumulative weights | the weights, in a fixed-value port |
| **spread** | N | whichever exit's destination has fewest values waiting | nothing it owns |

```
   comparator                        iterator
   ──────────                        ────────
   value ──→ ┌───┐ ─→ below          value ──→ ┌───┐ ─→ exit 0
             │   │ ─→ equal                    │   │ ─→ exit 1   cursor
   threshold │   │ ─→ above                    │   │ ─→ exit 2   moves on
   (a port)  └───┘                             └───┘             each run
```

**The iterator's exit is decided when its values are claimed, not when
it runs.** The cursor advances under the station's lock while the task
is being assembled, and the exit it landed on rides inside the task. So
two tasks assembled a moment apart carry different exits no matter
which of them finishes first, and the box function never sees the
cursor at all.

**`spread` is the only one that reaches outside its own station.** It
looks at how many values are waiting at each candidate destination and
picks the emptiest. That read is best-effort — a value can land between
the look and the send — and the walk is correct under every such race,
because the worst outcome is a slightly uneven split rather than a lost
or duplicated value. Ties go to the cursor, same as an iterator.

**`weighted`'s weights live in a fixed-value port**, which means they
are a dial somebody can turn while the program runs, for free, using
machinery that already exists. Nothing special is needed to make the
weights adjustable, because everything fixed is already adjustable.

### The seventh kind was never routing

The old design had a `nonlinearity` kind: read the value as a number,
push it into a ring of recent values kept on the station, work out the
running range from that ring, normalise against it, apply an S-curve,
and emit the shaped result.

**It is not a way of choosing an exit. It is a box that remembers.**
And a box cannot remember — two cores can be inside the same box
function at the same instant, so anything it kept would be shared
between them.

So it stops being a kind and becomes what the engine says state has to
be: a value on a wire.

```
   value ────────┬─────────────────────────────────────┐
                 │                                     │
                 ▼                                     ▼
          ┌─────────────┐                       ┌─────────────┐
          │ recalibrate │                       │    shape    │ ─→ out
          └─────────────┘                       └─────────────┘
                 │  new range                          ▲
                 └─────────────────────────────────────┘
                              the range, going round
```

Two ordinary boxes and one arrow that points backwards — which is legal
and, as 307 explains, is the engine's only mechanism for state.

**One honest caveat.** A station takes whatever is at the head of each
of its ports, so the range arriving at `shape` is not necessarily the
one computed from the value arriving beside it. For a calibration that
drifts slowly across thousands of values, that is fine. For anything
where the pairing must be exact, the two things have to be *one* value
on one wire — which is the general rule, and this is a good place to
learn it.

## Suggested implementation steps

1. Fill in the exit table's remaining rows, one function each, all
   reached the same way.
2. The comparator's threshold as a port typed to the box's return
   value, and the refusal at placement when that type has no ordering.
3. The cursor on the station, advanced at claim time, carried in the
   task.
4. `random` and `weighted` over the chip's generator — read inside the
   picker, never cached, so no state is kept anywhere.
5. `spread`'s look at downstream occupancy, with a comment at the read
   saying plainly why a stale answer is harmless.
6. Delete the seventh kind and add the two boxes that replace it to the
   launch library, as the worked example of state living on a wire.
7. A map per kind with a closed-form expected distribution, asserted
   over enough values that a wrong picker cannot pass by luck.

## Open questions

- *Does `spread` see enough to be useful?* It reads the occupancy of
  each destination's port, which is one number per exit. If the real
  bottleneck is two stations further down, the emptiest neighbour is
  not the shortest queue. Probably still better than round-robin,
  provably better than nothing, and worth measuring against `iterator`
  on a deliberately lopsided map before anybody relies on it.
- *Is reading the chip's generator cheap enough to do per value?* If it
  is a register read, yes. If it stalls waiting for entropy, no, and
  then `random` and `weighted` need a per-core stream seeded once —
  which is core state rather than box state, so it stays legal, but it
  wants knowing rather than assuming. The entropy sweep from phase 1
  has the numbers.
- *Should the number of exits be checked against the map?* An iterator
  wired to three exits and an iterator wired to one are both valid, and
  the second is almost certainly a mistake. That is a report rather
  than a refusal, and it belongs with 307's unfinished-work list.

## Blocked by

303, 306, and phase 2's delivery walk.

## Blocks

310, 312.

## Related

- [211 — The delivery walk](211-the-delivery-walk.md), whose first step
  this fills in
- [303 — Types, by name and by width](303-types-by-name-and-by-width.md),
  where orderings come from
- [307 — Everything wrong with a map, said at once](307-everything-wrong-with-a-map-said-at-once.md),
  which explains why the loop above is allowed
