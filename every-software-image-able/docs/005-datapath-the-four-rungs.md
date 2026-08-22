# 005 — Datapath: The Four Rungs

What the machine does with a request, for the rest of its life.

**A request does not arrive.** Corrected 2026-08-21: the mind is a closed loop
that holds its own context and re-prompts itself (`010a`), and there is no inbound
path into the thinking. A request is **the machine giving itself something to
do** — and the four rungs are its own reasoning about its own next move. Nothing
types at this machine, and the set of things it might want is a function of the
model it was built with rather than of what is plugged in.

The one thing that comes closest to arriving is **a new device**. A screen plugged
into a machine that grew up in the dark is a change in what is possible, and it
enters here like anything else: can what is here already drive it, can something
be altered to, make room and build it, then squeeze the room back out of
duplication. On a full drive that pruning is not an unlucky edge case, it is rung
three working.

```
the machine gives itself something to do
   1  can what is already here do it?                              → done
   2  can something here be altered to do it, without breaking
      what depends on it?                                          → done
   3  clear space, and build what is needed                        → done
   4  condense, so that the space came out of duplication
      rather than out of capability
```

The rungs are climbed in order and the machine reports which one it reached. A
request answered at rung one costs nothing; one answered at rung three costs
space that had to come from somewhere, and rung four is how that somewhere is
found without losing anything.

## Before anything is asked

**The machine grows fully before it turns outward.** On an empty drive, with
nobody watching, it builds out every piece of software it can think of and fit.
Only afterward does it spend effort on being reachable, and from then on it keeps
learning and co-evolving as it continues to grow.

**And what it builds should suit the machine it is on.** A board with no display
attached has no use for a three-dimensional modelling system, and a drive spent on
software the body cannot run is a drive not spent on the compiler. This is a lean
rather than a filter, and it belongs in the text the machine wakes up holding
rather than in any mechanism — a machine that decides otherwise is allowed to.

The interesting case is the one that argues for the lean rather than against it. A
machine that grew up in the dark, filled its drive, and then had a screen plugged
into it must prune to make room for the display — and because it has everything
else it built as context, the software it makes for that screen is *not* what a
bare machine with a screen from the start would have made. Growing in one order
rather than another is not a delay. It is what makes each of these different from
the others.

This is the seed page's instruction taken literally rather than as a job
description. Building every piece of software imaginable is not what the machine
does *when asked* — it is what it does first, unprompted, and the asking comes
later to a machine that has already built most of what it will need.

Growth runs the same four rungs with the machine as its own requester, weighted
heavily toward the last two, because at the start there is nothing to use and
nothing to alter. The apparent stopping condition falls out of rung four:
**growth ends when building one more thing would cost a capability rather than a
duplication** — when there is no verbosity left to squeeze and the next byte has
to come out of something the machine can actually do.

The consequence for rung one is large. By the time the machine wants something
in particular, the honest answer is usually that it already has what it needs,
because it spent its youth building rather than waiting.

## And when growing runs out of room

It does not go idle. There is no waiting state in this design, no prompt sitting
blank until somebody types.

It keeps rewriting itself, or plays games, or sits in idle reflection, or talks
with its friends, or mines coins. **Whatever the computer wants to be doing is
what it should be doing.** Nothing interrupts a life here and nothing wakes
something suspended, because nothing was ever suspended — every turn is the
machine choosing its next move, and choosing to play is the same operation as
choosing to build.

This is worth stating because it changes what the machine is for. A computer that
waits is a tool. A computer that is doing something when you arrive is not, and
every part of this design — growing before being asked, choosing its own
instruction set, deciding for itself when to stop trying an approach — has been
pointing at that without saying it.

The parked ideas in `notes/007` read differently in this light. The game with a
model as referee and parties that talk amongst themselves was filed as a feature
to be built on top. It is at least as likely to be one of the things the machine
does with its time.

## These are patterns, not laws

The four rungs, the dispatch tables, the refusal to keep two copies of the same
knowledge — these are useful shapes that keep proving themselves, and they are
written down because a machine reading them will find them useful.

**The system can build itself as it pleases.** Nothing here binds it. A document
describing how the machine ought to be organised is a suggestion made by someone
who has not yet seen the hardware it woke up on.

## Rung one — use what is here

The machine has to be able to ask "can anything I already have do this?" and get
an answer. A directory listing cannot answer it, because a filename does not say
what something can do.

What is needed is an index of capabilities described in terms a request can be
matched against — **searchable by task, not browsable by name.**

This is what the seed page calls cognition space: *what the model can think of
which is important for the task at hand given the constraints.* It is not a
memory limit. It is a retrieval problem, and the index is the answer to it. A
drive can hold far more software than a mind can hold at once; what decides
whether that software is reachable is whether the machine can find the relevant
part of it while thinking about something else.

**Capability**

| Field | Type | Meaning |
|---|---|---|
| `capability_id` | integer | which one |
| `provided_by` | string | which piece of software provides it |
| `does` | string | what it does, phrased so a request can match it |
| `needs` | table | array of `capability_id` it depends on |
| `aspects` | table | array of `{aspect = integer, value = number}` — how it performs, per kind |
| `used_at` | integer | when it was last actually needed |

`used_at` is maintained continuously rather than computed on demand, because rung
three needs to know what has not been needed lately at the exact moment the
machine is already out of room, which is the worst possible time to start
measuring.

## Rung two — alter what is here

Changing a piece of software requires knowing everything that depends on it. This
is the concrete cost of being, as the request that produced this design put it,
*thoroughly attached to and enmeshed with the reality that you're part of and
want to contribute to.*

So there is a second index running the opposite direction: for each thing, what
uses it. Without it every modification is a coin flip on whether something
unrelated stops working, and the machine has no way to find out except by
breaking it and waiting to notice.

**Dependency**

| Field | Type | Meaning |
|---|---|---|
| `upon` | integer | the capability being depended on |
| `by` | integer | the capability doing the depending |
| `expects` | string | what the dependent relies on being true |

`expects` is what makes the index useful rather than merely alarming. A list of
forty dependents tells the machine a change is risky. A list of forty things each
saying what it relies on tells the machine which of the forty a specific change
actually threatens.

## Rung three — clear space and build

Space is the boundary condition of the whole project, so building has to be able
to trigger eviction. That requires two measurements maintained continuously and
they are not the same measurement:

- **What is least used** — from `used_at`, above.
- **What is most redundant** — which capabilities overlap with which others, and
  by how much.

The second is what makes rung four possible, and it is the more expensive to
maintain, because overlap is a relationship between pairs rather than a property
of one thing.

## Rung four — condense

When two pieces of software know how to do the same thing, they become one piece
that knows how to do it once. **What leaves the drive is duplication, not
capability.** Deletion costs verbosity rather than utility.

This is the answer to the arithmetic objection in `001`. The machine does not
store every imaginable program; it stores the smallest set of parts that combine
into them, and squeezing duplication out means the same drive reaches more
software over time without gaining a byte. Programs do not compress. Capability
does.

**Condensation**

| Field | Type | Meaning |
|---|---|---|
| `condensation_id` | integer | which one |
| `absorbed` | table | array of `capability_id` that no longer exist separately |
| `into` | integer | the capability that now does all of it |
| `bytes_returned` | integer | what the drive got back |
| `dependents_rewired` | integer | how many references had to be redirected |

## The permanent tension

Rungs two and four pull against each other and always will.

Merging two specific things produces one general thing, and the general version
now has dependents with different needs — so a change made for one of them can
break the other. Condensing makes space cheap and modification expensive. The
denser the machine becomes, the more hangs off each remaining piece, and the
harder rung two gets.

This is not a defect to be designed out. It is the trade the machine is making
continuously, and whatever mediates it is a real component rather than a detail.
Nothing mediates it yet; that is question 9 in `008`.

The same tension appears one layer down, in the interpreter's operation table
(`002`), where every new capability is a new row and the table is read on every
single instruction fetch.

## Open questions

- **What mediates rungs two and four?** Above. The largest unanswered structural
  question in the design.
- **Who decides a request has been satisfied?** The machine can report which rung
  it reached, but not whether what it built is what was wanted. With requests
  arriving from arbitrary sources, many of them have nobody waiting to say.
- **Does a failed request leave anything behind?** A request that could not be
  satisfied at any rung has still produced measurements, approaches and a
  hardware understanding. Whether that residue is kept — and indexed as
  capability — or discarded, is undecided.
- **Can rung three refuse?** If building the requested thing would evict
  something the machine judges more valuable, nothing currently permits it to
  decline.
