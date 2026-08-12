# 208 — What an input port is

## Current behavior

**Nothing holds a value between the box that produced it and the box
that will consume it.**

## Intended behavior

**A port is the standing interface for one input of one station:
where its value comes from, how many bytes one value is, and the
storage it keeps. It lives on the station for as long as the station
does.**

A *cell* is one place where one value physically sits. The port decides
how a value is stored; the cell is where it lands.

### Three tags, one in effect

| tag | how it is read | how it is written | does it hold up readiness |
|---|---|---|---|
| **ring** | **consumed** — one value taken per run | queued behind whatever is waiting | **yes** |
| **static** | **peeked** — every run reads the same value | replaces what was there | no; always full |
| **none** | never. a station holding one can never run | by being given a source | **yes**, permanently |

A ring port is a stream; a static port is a dial. That is the whole
distinction.

**None is a state, not a value.** No null is invented and nothing is
ever handed to a box. It is what lets a program be assembled a piece at
a time, and — as 213 and 214 both discover — it is also how a program
parks and how a broken box takes itself out of service. One mechanism,
three uses.

**A port's cells are allocated when the station is placed, whatever the
tag currently is.** The size of one value is known from the box, so the
space is exactly right, and changing a port's source becomes a field
write rather than an allocation. Values already sitting in a port
survive a change of source — not freed, not drained. They are waiting
if it becomes a ring again. Throwing them away would silently discard
values a producer already handed over.

**A port is made of:**

| field | type | what it is |
|---|---|---|
| tag | `unsigned char` | ring, static, or none |
| elem_size | `int` | bytes per value. From the box's parameter type. |
| pages | pointer to a short array | where the cells live (see growth) |
| n_cells | `int` | how many, across all pages |
| bookmark | `int` | a hint at where to start looking. May be wrong. |
| value | the bytes | static only — the value lives here, not in a table |

### Every cell carries its own state, and that state is the lock

| state | meaning | who may touch it |
|---|---|---|
| **empty** | nothing here | a writer, by taking it |
| **reserved** | a writer owns it and is copying in | that writer only |
| **ready** | the bytes have landed | a reader, by taking it |
| **claimed** | a reader owns it and is copying out | that reader only |

```
       writer takes it           copy done
  empty ─────────────→ reserved ───────────→ ready
   ▲                                          │
   │                                          │ reader takes it
   │            reader finishes                ▼
   └──────────────────────────────────── claimed
```

Every transition is one compare-and-swap, so two cores can never own
one cell. That is the whole of the mutual exclusion, and it is **per
cell** rather than per station. No lock is involved on this path at
all. It is also the reason 201 had to happen first: on the machine
phase 1 left behind, these instructions are not defined.

**The state lives on the cell, not in a separate array of states.** An
array of states would put every cell's state in one or two cache lines,
so a writer at one end and a reader at the other would take the line
away from each other on every flip — a hardware cost no lock can
remove, because nothing is racing. Carried on the cell, a writer
working at cell three and a reader at cell zero touch different lines
entirely whenever the value is large, which is exactly when moving the
copying out of a lock was worth doing. This is the same false-sharing
rule as 203's stripes and 205's contexts, for the third time.

**Cells are not cleared when released.** Every write copies the port's
full element size, so a stale value is always completely covered.
The guarantee is not that a cell was cleaned — it is that a cell's
bytes are never read unless its state says ready.

### Finding a value is a scan from a bookmark

There are no head and tail indices. A reader starts at the bookmark and
sweeps forward, wrapping once, stopping where it started. The bookmark
advances as cells are used and **is allowed to be wrong** — a stale one
costs a slightly longer scan and nothing else.

That distinction is what makes everything here work: *a position must
be exact and is therefore computed from the capacity; a hint may be
wrong and therefore is not.* Nothing computes a location from the
capacity, so the capacity may change freely.

Reading the bookmark **once** per scan is what bounds the work. Reading
it again as other cores push it forward would let a reader chase it,
and a scan that can be outrun is a scan with no bound.

### Growth adds a page

```
   pages: ┌────────────┐ ┌────────────┐
          │ cells 0-9  │ │ cells 10-19│   ← a new page, appended
          └────────────┘ └────────────┘
   nothing is copied.  no existing cell moves.
   no window to get right.
```

Because no location is derived from the capacity, changing the capacity
disturbs nothing. This removes an ordering problem outright rather than
solving it: copying values across and then publishing means a value
taken during the copy exists in both places and gets delivered twice;
publishing and then copying means readers see an empty buffer while it
fills. Neither order is safe, because the real requirement was that
nothing else happen during the copy. With nothing copied, there is
nothing to protect.

**A port that keeps growing is a signal worth reporting.** It means one
input of a station is being fed faster than its siblings, and memory is
absorbing the imbalance while values wait for their partners. A
single-input station cannot do this — every arrival completes its input
set immediately — so growth here always means a multi-input station fed
unevenly. Ring growth in 204 means something different: consumers
slower than producers overall. Reading the two together is what locates
a bottleneck.

**Values may leave a port in a different order than they arrived.**
This is a real loss, taken deliberately. Values reaching one port from
two upstream stations were already in whatever order the cores happened
to produce them, so the order was arbitrary to begin with; and a
reader that gives up releases cells wherever they sit, so gaps open and
"the oldest" stops being findable without a search nobody wants to pay
for. It belongs written down as a stated non-guarantee, because
something that is merely not promised is where somebody builds on an
assumption nobody wrote down.

## Suggested implementation steps

1. The port record with all three tags, and accessors that read
   whichever one is in effect. No dispatch entry anywhere is allowed to
   be an absence — the *none* row answers "not filled" and "never
   claimable" explicitly.
2. Cells allocated at placement time, a named constant deep, sized from
   the box's parameter type. A port may be told its own starting depth;
   growth covers being wrong, so nobody has to be right.
3. The per-cell state machine, every transition a compare-and-swap —
   but with the copies still inside the station's lock at first, so the
   state machine can be proven correct while the old locking still
   guarantees it cannot matter.
4. Move the write copy out of the lock, then the read copy. Measure
   after each against a wide fan-in carrying large values, which is
   where the win is supposed to be and the only place it will show.
5. Paged growth, replacing nothing — there was never a copy to replace.
6. A test that a port cycles through all three tags while a station
   upstream delivers into it continuously, and nothing tears.
7. A test that a station with an unconfigured port never becomes ready,
   and becomes ready the moment that port is given a source.

## Open questions

- *How deep should a port start?* Ten is the other project's answer and
  it is deliberately a magic number, on the reasoning that a buffer
  which starts too small grows to whatever the program actually needs
  and then stops. On this device the allocator hands out pages, so the
  natural answer is instead "as many as fit in one page", which for a
  four-byte value is a thousand and for a two-hundred-byte struct is
  twenty. That is a different shape of guess and it may be a better
  one — a port's first page is free either way.
- *The bookmark is one shared number written by every reader.* That is
  a contended line on the hot path, accepted with open eyes because
  its cost is fixed no matter how large the port grows, and because a
  per-core copy would be a hint that is always cold, which has stopped
  doing the one job a hint has. If a measurement shows it mattering,
  publish progress occasionally rather than every time.
- *Do the cells want padding so each starts on its own line?* For large
  values they already do. For a four-byte value, padding to 64 bytes
  costs sixteen times the memory to remove a cost that only appears
  when two cores work on adjacent cells. Almost certainly not worth it,
  and worth measuring once so the answer is recorded rather than
  assumed.

## Blocked by

201 (compare-and-swap must be defined), 203, 207.

## Blocks

209, 210, 211.

## Related

- [207 — The station table](207-the-station-table.md), which these hang
  off
- [209 — The readiness check and the claim](209-the-readiness-check-and-the-claim.md),
  the only reader
- [211 — The delivery walk](211-the-delivery-walk.md), the only writer
