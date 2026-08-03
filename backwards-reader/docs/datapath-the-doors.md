# datapath — the doors

Getting thousands of small inferences onto three little machines, a local
GPU, and a workstation, and knowing whether it helped.

## A door

An address that answers HTTP. Nothing more is assumed. What is behind it —
one `llama-server`, three of them behind a proxy, a model split across a
rack over RPC — is the far side's business, and this program is careful not
to be able to tell.

The roster is `input/cluster`, one line per door:

    name host port kind

`kind` is `mirror` (answers `/completion`), `angle` (answers `/embedding`),
or `both`. The format matches the porch in `gif-generator` deliberately;
two programs on one network should not disagree about how machines are
named.

In memory a door is:

| Field | Type | Meaning |
|---|---|---|
| `name` | string | as written in the roster |
| `host` | string | dotted quad or hostname |
| `port` | number (integer) | TCP port |
| `kind` | string | `"mirror"`, `"angle"`, or `"both"` |
| `waiting` | number (integer) | units dispatched to this door and not yet answered |
| `cost_ms` | number (float) | observed milliseconds per unit, exponentially decayed |
| `answered` | number (integer) | how many units this door has completed |
| `failed` | number (integer) | how many times it errored or timed out |
| `alive` | boolean | whether the last health check succeeded |

`cost_ms` starts at a large pessimistic value so an unmeasured door does
not win the first race and swallow the queue before anything is known about
it. It decays toward observed reality at a fixed rate per answer.

## The price

    price(door) = door.cost_ms * (1 + door.waiting)

Cheapest door takes the next unit. That is the entire routing rule, and the
reasoning behind it is in `strategems/price-as-a-load-balancer.md`.

Two properties matter here:

**A dead door prices itself out.** Failure raises `cost_ms`; repeated
failure raises it without bound. Death is just the limit of slowness, so
there is no separate failover path to get wrong.

**This machine is a door.** `here` is in the roster like any other, with a
price computed the same way from the same measurements. When local work is
cheaper than the cheapest remote door, the dispatcher keeps the unit. The
crossover point is therefore not a tuned constant — it is re-decided per
unit from live measurements and cannot go stale.

## Health, and the refusal to limp

At startup every door in the roster is asked for `/health`. A door that
does not answer is a **hard error** and the reading does not start.

This is deliberate and is the opposite of the usual choice. A cluster that
quietly runs on two of three machines still produces output, so nothing
looks wrong — but every timing is now wrong, the crossover measurement is
wrong, and the conclusion drawn from the run is wrong. Since measuring the
cluster is one of the things this project is *for*, a silent degradation
corrupts the actual product. Better to stop and say which door is dark.

A door that dies mid-reading is different: the work is real and partly
done. There, the price mechanism handles it — the door gets expensive, work
routes elsewhere, and the record notes which units were re-dispatched and
why. That distinction is recorded in the run's log rather than inferred.

## Dispatch

One coroutine per in-flight unit over a shared task stack. The socket read
yields, so hundreds of units can be outstanding against five doors on one
OS thread. The limiting resource is door capacity, not the scheduler.

    push(unit)              -- onto the shared stack
    resume_until_drained()  -- run coroutines until the stack empties

Each door has a concurrency cap — how many units it will accept at once,
read from the roster or defaulted from what `llama-server` was started
with. Exceeding it does not go faster; it just moves the queue from this
program into the far side's scheduler, where the price mechanism cannot see
it. Keeping the queue local is what makes `waiting` an honest number.

## The crossover measurement

A separate utility, run on demand, not part of a reading. It answers: at
what unit size does sending work to a door beat doing it here?

The method is to take a fixed set of units of increasing size, run each
both ways with everything else held still, and report the two curves and
where they cross. The output is a table of measurements written to
`tmp/shared-memory/`, and a plot rendered by the viewing side. No number
from it is ever hard-coded anywhere; the routing already uses live prices,
and the measurement exists so a person can see the shape of the curve.

The shape is the interesting part, and the reason the utility exists at
all. Cost per unit falls as units get larger (the per-request overhead
amortizes) but latency per unit rises, and the two do not trade off the
same way on a fast local GPU as on three small remote machines. Where the
curves cross is where "use more doors" stops paying — and pushing that
point further out is the design goal that most of the rest of this program
is arranged around.

## Related

- `strategems/price-as-a-load-balancer.md` — the rule, stated generally
- `docs/architecture.md` — why this workload suits a cluster so well
