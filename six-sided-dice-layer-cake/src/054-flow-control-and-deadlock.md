# 054 — Proving it cannot stop

```meta
phase  | 7
issues | 705
```

## Why a proof and not a test

There is no operating system. Nothing watches for a hang, nothing can preempt,
and once a cube is sealed nothing can be probed. **A deadlock in this design is a
cube that stops and cannot be diagnosed.**

The system is small enough to reason about: six requesters, one switch, banked
tiers, one buffer per stage, and a fixed credit count. The argument does not need
to be subtle, it needs to be complete.

## The three ways it could stop

```drawing
the dependency graph, and the one edge that closes it [not-dimensioned]

   a face holds credits ──waits for──▶ a response
        ▲                                  │
        │                                  │ needs
        └──── is returned by ──────────────┘

   broken by: request and response never share a queue


   stage n writes buffer ──waits for──▶ stage n+1 to consume
        ▲                                  │
        │                                  │ waits for
        └──── stage 0 re-entry ────────────┘

   broken by: stage 0 never blocks on a full buffer; it declines
   to admit a new microbatch instead
```

**Credit deadlock.** A face holds credits waiting for a response that cannot be
produced because the responder needs a credit the face holds. The cure is
separate request and response channels that never wait on each other — and the
separation must be **complete**, because a single shared queue anywhere between
them reintroduces the cycle. `C-054-1` is that statement.

**Buffer deadlock.** The sieve is a ring: stage five's output re-enters at stage
zero. A ring of buffers each waiting on the next is the classic deadlock, and it
is broken by a rule rather than by a buffer — **stage zero never blocks**. When
its buffer is full it declines to admit a new microbatch, which is a decision it
can always make, rather than waiting for one it cannot.

**Starvation.** Not a deadlock — everything progresses — but a face never served
stalls the pipeline behind it anyway. `037` claims starvation freedom; here it is
checked against the real traffic including the spout and the scrubber, which
`037` placed at low priority and which must therefore still be shown to finish.

## Bounds, not absences

For each client class: the longest it can wait, derived from the credit count,
the arbitration quantum and worst-case contention. `053` sizes its buffers from
those and `049` sets timeouts that mean something.

**Timeouts are the last line and they belong here.** A barrier that never
completes must eventually raise a fault rather than waiting forever, and the
timeout must exceed the proven worst case by a stated margin — otherwise it fires
in normal operation and the machine reports faults it does not have.

## Symbols

```symbols
n_channel      | 1 | given | 2      | independent channels: request and response, sharing no queue anywhere
n_ring_break   | 1 | given | 1      | stages at which the ring is broken by a stage that never blocks
f_timeout_marg | 1 | given | 100.0  | how many times the proven worst case a timeout must be set at

t_wait_worst   | s | derived | max(max(t_wait_face, t_wait_spout), t_wait_scrub) | the longest any client can wait, across all three classes
t_timeout_bar  | s | derived | t_handoff * f_timeout_marg | timeout on a staging barrier
t_timeout_txn  | s | derived | t_link_rt * f_timeout_marg        | timeout on a transfer
n_resource     | 1 | derived | n_channel + n_stage + n_port      | resources a client can hold while waiting for another, which is the size of the graph the argument has to cover
f_wait_stage   | 1 | derived | t_wait_worst / t_stage            | the worst wait as a share of a pipeline stage
```

## Constraints

```constraints
C-054-1 | n_channel == 2               | request and response are two channels and share no queue. Asserted as a count because the property itself cannot be written in this notation, and it is the constraint most easily satisfied in a diagram and violated in an implementation
C-054-2 | n_ring_break >= 1            | the staging ring must be broken somewhere. Stage zero declining to admit a microbatch is a decision it can always make; every other stage waiting on the next is a decision it cannot
C-054-3 | t_timeout_bar > t_handoff * 1e-9 | a barrier timeout must exceed the handoff it is timing, by the stated margin
C-054-4 | t_timeout_txn > t_link_rt    | and a transfer timeout must exceed a round trip
C-054-5 | f_wait_stage < 0.01          | the worst wait any client can suffer must be under a hundredth of a pipeline stage, so that arbitration never appears in 080's model
C-054-6 | f_timeout_marg > 10          | timeouts must sit well clear of the proven worst case, or they fire in normal operation and the machine reports faults it does not have
```

## What is still open

**The proof is a paragraph and the constraints are a count.** `C-054-1` asserts
that there are two channels, not that they share no queue; `C-054-2` asserts a
ring break exists, not that it is where it is claimed. The notation cannot hold a
dependency graph, so the actual acyclicity argument lives in prose and is checked
by a reader.

**Nothing covers a request being refused rather than delayed.** `037` noticed the
same gap from the arbiter's side. Every bound here assumes a client eventually
gets served; a client that is told *no* and must retry is a different system, and
if the core ever gains a mechanism that refuses — a bank taken offline by `040`,
say — this argument does not cover it.

**Timeouts have no defined recovery.** They raise a fault in `049`. What happens
next is not specified anywhere, and on a machine with no operating system the
honest answer may be that there is nothing to do but halt.
