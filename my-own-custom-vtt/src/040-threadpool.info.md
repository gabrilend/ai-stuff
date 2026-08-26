# 040-threadpool

A range and a function. Nothing else.

Every parallel pass in this project is the same shape — walk a contiguous span of
records — because the world is flat arrays, so splitting work is arithmetic. This
offers exactly that and deliberately no task queues, futures, or work stealing:
machinery for problems this project does not have, each of which would be a place
for a bug that only appears under load.

| Function | In | Out |
| --- | --- | --- |
| `pool_start` | worker count, or 0 to size from the machine | pool, or NULL |
| `pool_stop` | pool | — |
| `pool_run` | pool, function, context, item count | — (a barrier: every span is complete when it returns) |
| `pool_worker_count` | pool | count |
| `pool_default_worker_count` | — | cores minus one |

A `pool_function` takes `(context, first, last)` — a half-open span of item
indices.

## No locks inside a pass, and that is load-bearing

No pass writes where another instance of itself reads. That is
buffer-then-resolve, established at the design level rather than defended at the
code level, and it is why the pool needs no lock primitives at all — only a way
to start N workers and wait for them.

**If a pass ever needs a mutex, the pass is the bug, not the pool.** The first
person to hit a race will otherwise reach for a lock, it will work, and the
design will quietly be over.

## Two details that matter

**Threads are created once, at start, and never again.** Creating one during a
tick is a stall nobody expects and nobody measures.

**The generation counter, not the wakeup, says there is work.** A condition
variable may wake a thread for no reason at all; a worker trusting the wake alone
would run somebody else's span twice.

**The remainder is spread across the first few workers**, not piled on the last.
A barrier waits for its slowest member, so a last worker carrying an extra
thousand records makes every other thread idle for as long as those take.

## A pool of one is a real mode

It runs everything on the calling thread and starts no threads at all. Not a
degraded fallback — it is how the determinism harness proves that thread count
changes nothing, so it is tested like any other configuration.

The phase 2 demo measures the sight pass at 1, 2, 4, and 8 threads and reports
both wall time and processor time. Wall falls while processor climbs; that gap is
the coordination being paid for, and it is the shape a parallel pass is supposed
to have.
