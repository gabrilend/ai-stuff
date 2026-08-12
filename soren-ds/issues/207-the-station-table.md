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

## Open questions

- *When can the old destination array be freed?* A walker may still be
  inside it when rewiring swaps the address. Freeing immediately is a
  use-after-free; never freeing leaks. The cheapest answer on a device
  with no interrupts: a core is only ever inside such an array between
  taking a task and finishing its delivery, so once every core has
  passed through the run loop once, no walker can still hold the old
  address. That needs a counter per core and one comparison, and it
  wants writing down properly rather than being assumed here.
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
