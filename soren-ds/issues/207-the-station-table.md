# 207 — The station table

## Current behavior

**Nothing represents a box that has been placed.**

The old design had one table listing every box the kernel knows about.
That is a catalogue of *code* — it says `add` takes two numbers and
returns one. It does not say that there are eleven adders currently
running, each with its own waiting inputs and its own wires out.

Two different things needed two different words and only had one:

| word | what it is | how many |
|---|---|---|
| **box** | the code. A C function, its parameter types, its name. | one per source file |
| **station** | one placement of a box: its own inputs, its own wires, its own lock. | as many as anyone places |

This issue builds the second. The first arrives in phase 3, when the
build path can read box sources and write the catalogue out
automatically.

## Intended behavior

**Every station lives in one table, and a station is addressed by its
position in that table — a number, never an address.**

There is no separate "map" object anywhere in this design. A map is
simply whichever stations currently exist and are wired to each other.
Four apps, the compositor, and the input router all live in the same
table at once; what separates them is the wiring, not the storage.

**Why a number rather than a pointer:**

| | |
|---|---|
| half the size | two per wire, and there are many wires |
| survives being written down | a number means something in a log or on screen; an address is noise |
| survives the table growing | which is the whole of the next section |

**The table grows by adding a shelf, never by reallocating.**

A shelf is one allocation holding a fixed number of station records,
and the table is a short array of shelf addresses. Station *n* lives at
position *n* within shelf *n ÷ shelf size* — one shift and one mask
when the size is a power of two.

```
   shelves:  ┌────────┐  ┌────────┐  ┌────────┐
             │  0..63 │  │ 64..127│  │128..191│  ← one page each
             └────────┘  └────────┘  └────────┘
                  ▲           ▲           ▲
             ┌────┴───────────┴───────────┴────┐
             │    short array of addresses     │  ← this is what grows
             └─────────────────────────────────┘

   adding a shelf moves nothing.  every station stays exactly
   where it was, at the address it was always at.
```

**A station must never move, and the reason is its lock.** Each station
record carries its own lock inside itself. A lock is identified by
where it lives — a core spinning on the one at the old address is not
released by an unlock at the new one, and copying the bytes of a lock
somebody might be holding is not a defined thing to do. Reallocating a
flat array moves every station and therefore every lock. Shelves keep
the guarantee instead of arguing with it.

**A shelf is one page**, because 203 hands out pages and a page holds a
comfortable number of records. It is a constant with a name, and being
wrong about it is cheap in both directions: too small and the address
array grows a little more often, which is safe because it holds
addresses; too large and the last shelf has some unused records in it.

**A station is made of:**

| field | type | what it is |
|---|---|---|
| lock | spin lock | held for growth, rewiring, writing a static, changing a port's source. **Never on the delivery path.** |
| call | function pointer | the box this station runs |
| kind | `unsigned char` | plain, comparator, or iterator. Consulted only on the way out. |
| ports | pointer to an array | the inputs, in the box function's parameter order (208) |
| n_ports | `int` | how many |
| exits | pointer to an array | where output goes. One for plain, three for a comparator, however many an iterator has. |
| cursor | `int` | which exit an iterator uses next. Unused by the others. |

Everything that varies in size hangs off a pointer, so the record
itself is uniform and the table stays indexable.

**An exit's destinations are one immutable array, and the exit holds
its address.** Rewiring never edits that array — it builds a whole new
one and swaps the address in a single atomic write. A delivery reads
the address once and walks whatever it got, which nobody will ever
modify. No lock, no copy, and no chance of seeing a half-edited set.

**Arrows are drawn in batches, and the reason is fairness rather than
tidiness.** Attach one wire out of a station and values start going
down it immediately; attach the second a moment later and it has
already missed everything the first one received. Attaching a whole
port's worth at once means every destination starts from the same
instant. It also closes the only window that would have needed output
buffering — a station wired in during a build could otherwise start
running before its own outgoing arrows existed, and its results would
go nowhere.

```
   exit ──→ ┌──────────────────────────────┐
            │ {station 7, port 0}          │
            │ {station 9, port 1}          │  ← nobody ever edits this
            │ {station 12, port 0}         │
            └──────────────────────────────┘

   rewiring builds a new one and swaps the arrow. a walker
   already inside the old one finishes reading a coherent set.
```

Both numbers in a destination are needed. Delivery examines *all* of
the destination station's ports to decide readiness, so it must be able
to name the station, not merely land somewhere inside it.

**The count is what readers race on, and it only ever grows.** A core
reading a stale, smaller count does not see the newest station, and
that is harmless — a station nothing is wired to yet cannot be reached
by any delivery, and the wire that will reach it is drawn after the
station exists. The single ordering rule is: build the station
completely, then publish the count that reveals it.

**Removing a station is not possible, and that is deliberate.** An
index is a position; reclaiming one means either leaving a hole every
walk must learn to skip, or renumbering, which invalidates every wire
at once. A station that should stop running has its inputs unwired
instead — see 213 and 214, where this turns out to be the mechanism for
both parking a program and removing a broken box.

## Suggested implementation steps

1. The station record and the shelf array, with adding a station as the
   only way one comes into existence — the table starts empty and grows
   the same way while a program is being built as it does at runtime.
2. Index arithmetic: shift and mask. Measure it against a flat array's
   single add before anything is built on top, because it lands on the
   delivery path.
3. Publishing the count as a number that only increases, with the
   build-then-publish rule written as a comment at the store.
4. Exits and destination arrays, with rewiring as build-new-and-swap.
5. A test that floods one station's input through several growths and
   confirms every station's address is unchanged.
6. A test that several cores adding stations at once all succeed, no
   two sharing an index.

### Old arrays go to a scrapyard, not a bin

A walker may still be inside the old array when rewiring swaps the
address. Freeing it then is reading memory somebody is still inside;
never freeing it leaks one array per rewire.

**Do the simple thing first: retire, don't free.** The old array goes
on a list and stays there until the program is torn down. A program
that rewires a few dozen times leaks a few kilobytes and nobody
notices. Three lines, and enough for everything in phase 2.

**Then, for a program that rewires continuously** — a control loop
turning knobs forever — they have to come back:

| | |
|---|---|
| each core keeps a **private counter**, on its own cache line, written by nobody else | one uncontended write, no coordination at all |
| it is bumped at the **start and end of a whole task** — run the box, deliver, free | so it reads **odd while inside** and **even while not** |
| retiring an array files it alongside a snapshot of every core's counter | |
| a later rewire sweeps: a core whose counter is now **even**, or **differs from the snapshot**, cannot be holding it | when all four pass, free it |

Nothing waits and nothing spins. A core with no work is asleep and
therefore even, so it passes without ever having to move — which is
what would otherwise deadlock the sweep against an idle device. The
counters are wide enough that one cannot wrap all the way back to its
snapshot and read as unchanged.

**The window is the whole task, not just the delivery.** A counter
around the walk alone would be tighter, and phase 4 needs the wider one
anyway to answer whether a core is inside a *box* — earlier in the same
task — before unloading code somebody just recompiled. One mechanism
answering both beats two that drift apart.

**The scrapyard owns a lock, and it is against double-freeing rather
than against tearing.** Two things touch it and only one is obvious: a
sweep, and teardown. Take the lock, confirm the array is still filed,
unfile it, free it — all under one hold, so a second arrival simply
does not find it. **The lock is a leaf: nothing else may be acquired
while it is held.** Written as a rule here rather than left to be
inferred, because a lock-ordering cycle is exactly the thing somebody
builds later having had no way to know.

This takes back nothing. The lock being removed is the one on the
delivery walk; the scrapyard is touched when wiring changes and when a
program ends, and never in between.

## Open questions
- *Does a station keep its name at runtime?* Writing the running set
  back out as something a person can read requires it, and so does any
  error message worth reading. Costs one pointer per station. Almost
  certainly yes, but it belongs to the issue that builds the dump.
- *Is one global table right when four apps share it?* It follows from
  a map being nothing but the current set of wired boxes, which is the
  simpler model. The thing it gives up is being able to say "tear down
  everything belonging to that app" in one operation — which becomes
  "unwire this list of stations" instead.

## Blocked by

201, 203.

## Blocks

208, 209, 210, 211.

## Related

- [208 — What an input port is](208-what-an-input-port-is.md), what
  hangs off `ports`
- [211 — The delivery walk](211-the-delivery-walk.md), which reads the
  destination arrays
- [213 — Asked to stop, and parking](213-asked-to-stop-and-parking.md)
- [003 — Threading model](../docs/003-threading-model.md), which this
  is the storage for
