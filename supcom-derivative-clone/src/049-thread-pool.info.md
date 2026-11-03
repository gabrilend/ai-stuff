# 049-thread-pool

Slices the tick's sliceable rows into ranges of unit rows and runs each range;
serial by default, the same answer at any worker count.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

The rule the pool stands on: **a sliced system may read anything and write only
its own slice.** A slice is a range of unit rows. The tick's dispatch table
(issue 105) flags the sliceable rows (move, sight-and-aim, fire), and
`advance` runs each of them through `run_sliced`:

1. The row's `before` step, if it has one, runs once, unsliced. This is the move
   pass's occupancy, which its slices read.
2. The unit rows, one to `top`, are split by `slice` into as many contiguous
   ranges as there are workers.
3. The backend runs the row's `run_slice` over every range and returns when all
   are done.

**The backend is an interface.** The one built, and the default, is `serial`:
the ranges run one after another, lowest first, on the calling thread. A
threaded backend needs a threading library (effil or lanes) vendored into libs/.
That is an open item for Ritz; such a backend would add itself to `BACKENDS`
and change nothing else. One thing it would have to keep: the fire pass appends
shots in unit-row order, so each range's shots must join the queue lowest range
first, for instance through a stretch of the queue per range. `configure`
refuses a backend nobody has built and says what it would need.

**The worker count** comes from `input/workers`: a whole number, or `cores` for
the machine's processor count (`getconf`). An absent file means `cores`. The
headless runner's `--workers` beats the file, and the report prints the count.
The count is a setting of the process, never of the world, so the fingerprint
does not fold it.

**Determinism does not depend on the pool.** Because each range writes only its
own rows, the result is the same at one worker or seven. Phase 2's test plays
one seed both ways and compares the fingerprint every ten ticks.

**The rule is checkable.** `trace_writes` runs a body and lists every slot of
the world's groups whose value it changed. `outside` runs one row's slice
function on one range and names the first unit row it wrote outside the range.
Phase 8's test uses the first, and phase 2's uses the second on every sliceable
row.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `slice(count, workers)` | rows from zero; workers from one | at most `workers` ranges `{first, last}`, contiguous, covering one to `count` once, no two differing by more than one row; none for no rows |
| `run_sliced(system, world)` | a tick row with `run_slice` (and maybe `before`); a world | the ranges it ran |
| `trace_writes(body, world)` | a function; a world | every changed slot, `{array = group, field = field, index = slot}`, in layout order |
| `outside(world, run_slice, first, last)` | a world; a slice function; a range | `"unit.<field>[<row>]"` for the first unit row written outside the range, or nil |
| `configure(workers, backend)` | a whole number from one; optionally a backend's name | nothing; refuses a backend not in `BACKENDS` |
| `workers()` | | the worker count and the backend's name |
| `read_workers(root)` | a project root | the count `input/workers` asks for; refuses anything but a number or `cores`, naming the file |
| `cores()` | | the machine's processors online, or one |
| `BACKENDS` | | backends by name; `serial` only |

## Data structures it owns

Only its settings, the worker count and the backend, which belong to the
process and not to the world. It writes nothing in the world itself; the
systems it runs do.
