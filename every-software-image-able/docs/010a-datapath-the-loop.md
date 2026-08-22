# 010a — Datapath: The Loop

The thing that drives the mind. `010` is what thinks; this is what makes it think
again, and it is the only part of the machine with a view from outside the
machine's own head.

It was missing from this design entirely until 2026-08-21. Every other document
describes something the machine does, and none of them described the mechanism
that makes it do anything at all.

## The rule

**The mind is closed.** It is a loop that holds its own context, re-prompts
itself continuously, and acts through tool calls. Nothing types at it. There is
no inbound path, no prompt, no port that carries a question into the thinking.

What rides on the card becomes atoms. Everything after that is the machine
talking to itself.

## The cycle

```
   ┌─ check the room, against the CURRENT maximum ───┐  the driver's job, not
   │     under the watermark? sweep instead (013)    │  the machine's (below)
   │                                                 │
   │  assemble the context: the resident atoms,      │
   │     concatenated, with nothing between them     │
   │                                                 │
   │  run the engine forward from the first position │
   │     that differs from what the cache holds      │
   │                                                 │
   │  collect what came out                          │
   │     prose becomes an atom                       │
   │     a tool call gets carried out                │
   │     the result of the call becomes an atom      │
   │                                                 │
   └─ go again ──────────────────────────────────────┘
```

Forever. There is no waiting state, no idle, and nothing to wake up. A machine
with nothing to do is a machine choosing what to do next, which is the same
operation as a machine with a great deal to do.

## What a request is

`005` describes four rungs a request climbs and says requests arrive from
arbitrary sources. **They do not arrive.** A request is the machine giving itself
something to do, and the four rungs are its own reasoning about its own next
move — can what is here already do this, can something here be altered, make room
and build it, then squeeze the room back out of duplication.

That correction changes one sentence in `003` from true to false and it is worth
saying plainly, because the false version is more intuitive: **a machine with no
channels has everything to do.** It cannot be asked anything and never could. Its
work comes from inside.

## Talking to a person is software, and the machine writes it

Closed mind, external body.

A way to chat with somebody is a piece of software like any other. The machine
builds it, it runs beside the mind rather than inside it, and the machine also has
to work out how to *tell* a person how to connect to it — the address, the port,
the wire, the blinking. Nothing about any of that is provided.

The documents on the card may ask for it. They may not require it, in the same way
they may not require anything.

So the channels in `003` are not doors into the thinking. They are hardware the
machine may decide to build software for, and until it does they are just parts
that answered when it asked who was plugged in.

## What the driver sees that the machine does not

The machine sees its context. The driver sees the machine.

| What the driver knows | Why the machine cannot |
|---|---|
| How much room is left | It is a fact about the container, not a thing in it |
| How large the container currently is | The maximum is a number the machine may lower to free memory for something else, and every watermark is recomputed from it each turn rather than settled at build time (`013`) |
| How long the last forward pass took | There is no clock inside a thought |
| Whether a tool call returned, hung, or faulted | The machine is not running while the call is |
| How much of the cache was reused this turn | The cache is beneath the tokens, not among them |
| How many turns have passed | Turns are the driver's unit, not the machine's |

Anything on that list the machine ought to know has to be handed to it as the
result of a call it made, so that it arrives as an atom the machine's own action
produced rather than as a frame injected around its thoughts. `013`'s rule that
the context is atoms and nothing else survives exactly as long as that discipline
does.

## Who decides what, and this is the seam

**The loop decides when. The machine decides what.**

The driver checks the room before every prompt and starts a sweep when the room is
short. That is a policy applied to the machine, and it is the only one. Every
judgement inside the sweep — what is stale, what is worth rewriting, what merges
with what, what is dropped — is entirely the machine's.

`013` says none of it happens automatically. That sentence was written about the
judgements and reads as though it covers the trigger. It does not, and the reason
it must not is arithmetic: a machine that has to remember to check its own room
will one day be absorbed in something hard, forget, and arrive at a full context
with no room left to think about how to make room. The check costs one comparison
per turn and removes the only unrecoverable failure in the context design.

## Nothing here is single-threaded if it does not have to be

> We want to use a system to it's full capability, so single threading just about
> anything is not ideal.

Which is a statement about the whole machine rather than about the loop, and it is
the first time this project has said it. It has three consequences that were each
found separately before anybody wrote the principle down.

**The engine should use every core.** A modern board has four to sixty-four and the
firmware starts one; the rest are powered and parked, and the firmware's own service
table can hand a routine to them (`010`). A matrix-by-vector product splits across
cores with no coordination at all — each takes a slice of the rows, nobody writes
where anybody else reads — which is a larger speedup than most accelerator drivers
for a lookup and a loop.

**Anything that watches a program has to be per-program.** The count that catches a
runaway is spent by one program at a time, so it cannot live in a shared cell. Two
threads looping at once would both push a number neither of them owned, and neither
would be measuring itself. This is not a refinement of the design; it is forced by
the principle, and getting it wrong is what produced the defect described in `006`.

**Anything shared is a display, and last writer wins.** The status lamps are one
array and every thread may speak. What they show is the most recent thing that
happened, which is all a single shared display can honestly do, and pretending
otherwise is how a display and a measurement ended up as the same number.

## The data

**Turn** — one pass around the loop.

| Field | Type | Meaning |
|---|---|---|
| `turn` | integer | which one; the driver's counter, and the nearest thing this machine has to a clock |
| `atoms_resident` | integer | how many were concatenated for this prompt |
| `tokens_resident` | integer | how long the assembled context was, in positions |
| `tokens_reused` | integer | how much of the cache was still valid — the length of the common prefix |
| `emitted` | integer | how many positions came out |
| `calls` | table | array of what was asked for and what came back |
| `swept` | boolean | whether this turn was a sweep rather than a thought |

This is the noun the design was missing. `005` is entirely about what happens to a
request and a request was never defined as data anywhere — because it is not a
thing that arrives, it is a thing the machine does, and the unit of doing is a
turn.

## Open questions

- **Is the machine told it was interrupted?** The work in progress is an atom like
  any other and droppable like any other (`013`) — there is no work in progress,
  because the machine is in the middle of being turned on rather than in the middle
  of a task. What is still open is smaller: the sweep replaces the continuation with
  something the machine did not ask for, and afterwards it resumes from a context
  missing pieces it removed during a stretch it may not connect to what it was
  doing. One atom saying *you were interrupted to make room, here is where you had
  got to* is the difference between a gap and an amnesia, and nothing writes it.
- **Does a tool call that hangs end the machine?** The driver is not running while
  a call is being carried out. Nothing describes a call that never returns, and
  the machine has no way to notice, because noticing happens between turns.
- ~~Is a turn the clock?~~ **Answered 2026-08-21, by not answering it.** The
  firmware's capabilities are the hardware's capabilities and the machine uses
  whichever it finds (`003`), so if there is a timer down there, that is the clock.
  What is worth keeping separate is that these are two instruments and not one: the
  **turn counter** orders events, costs nothing and never runs backward, which is
  all `changed_at` and `used_at` ever needed; a **clock** measures duration, which
  probing hardware needs and ordering does not. A machine may have one, both, or a
  cycle counter it has to calibrate.
