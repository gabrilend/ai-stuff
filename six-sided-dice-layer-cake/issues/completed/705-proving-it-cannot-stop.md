# 705 — Proving it cannot stop

Produces `src/054-flow-control-and-deadlock.md`.

## Current behavior

**Partly done, and the blueprint says which part.**
`src/054-flow-control-and-deadlock.md` exists with the dependency graph drawn,
both cycles identified, and a rule breaking each: request and response never
share a queue, and stage zero never blocks — it declines to admit a microbatch,
which is a decision it can always make, where waiting for the next stage is one
it cannot.

Six constraints, and bounds rather than absences: a worst-case wait per client
class, and timeouts set well clear of them so they do not fire in normal
operation.

**The proof is prose and the constraints are counts.** `C-054-1` asserts there
are two channels, not that they share no queue. `C-054-2` asserts a ring break
exists, not that it is where it is claimed. The notation cannot hold a dependency
graph, so the acyclicity argument is checked by a reader — **which is exactly the
kind of thing this project set out to stop relying on**, and it is the honest
state of this ticket.

**Nothing covers a request being refused rather than delayed**, and **timeouts
have no defined recovery.**

## Intended behavior

**A proof that the sieve cannot deadlock or livelock, and a bound on how long
anything waits.**

### Why a proof and not a test

There is no operating system. Nothing on this machine watches for a hang, nothing
can preempt, and once a cube is sealed nothing can be probed. **A deadlock in this
design is a cube that stops and cannot be diagnosed**, and the only place to catch
it is before it is built.

The good news is that the system is small enough to prove things about: six
requesters, one switch, thirty-two banks, one buffer per pipeline stage, and a
credit scheme with a fixed count. That is a finite state space and the argument
does not need to be subtle.

### The three ways it could stop

**Credit deadlock.** A face holds credits waiting for a response that cannot be
produced because the responder needs a credit the face holds. The standard cure is
to separate request and response into channels that never wait on each other, and
the blueprint must show that the separation is complete — a single shared queue
anywhere between them reintroduces the cycle.

**Buffer deadlock.** Stage *n* cannot write its staging buffer because stage *n+1*
has not consumed the previous contents, and stage *n+1* cannot proceed because it
is waiting on something stage *n* holds. The sieve is a ring in the sense that
stage five's output re-enters at stage zero, and **a ring of buffers each waiting on
the next is the classic deadlock**. The cure is either an extra buffer stage or a
rule that stage zero never blocks, and this blueprint must choose one and prove it.

**Starvation.** Not a deadlock — everything is making progress — but one face never
being served by `504`'s arbiter. The pipeline behind it stalls anyway. `504` claims
starvation freedom; this blueprint is where the claim is checked against the actual
traffic, including the spout and the scrubber, which `504` placed at low priority
and which therefore must be shown to still finish.

### What must be produced

A **bound**, not just an absence. For each client class: the longest it can wait,
derived from the credit count, the arbitration quantum and the worst-case
contention. `704` needs those bounds to size its buffers and `609` needs them to
set a timeout that means something.

**Timeouts are the last line and they belong here.** A barrier that never completes
must eventually raise the fault in `609` rather than waiting forever, and the
timeout must be longer than the proven worst case by a stated margin — otherwise it
fires in normal operation and the machine reports faults it does not have.

## Symbols this must publish

Channel count and their independence. Buffer count per stage. Worst-case wait per
client class. Credit count per channel. Timeout value per barrier type and its
margin over the proven bound. The ring-breaking rule.

## Constraints this must assert

- Request and response channels share no queue. Enumerated over the path, because
  this is the constraint that is easy to satisfy in the diagram and violate in the
  implementation.
- The staging ring is broken by the stated rule, at every one of the six stages.
- Every timeout exceeds its proven worst-case bound by the stated margin.
- Worst-case waits are inside `704`'s tolerances.

## Suggested implementation steps

1. Enumerate the resources and who can hold what while waiting for what. The
   dependency graph is small; draw it.
2. Show it is acyclic, or name the edge that closes it and the rule that removes
   it.
3. Derive the bounds rather than asserting freedom.
4. Set the timeouts from the bounds and assert the margin.

## Blocks

`609`, `1204`, `1205`.

## Blocked by

`504`, `506`, `703`, `704`.

## Related documents

`009` entry S1 is a scheduling question that touches this one.
