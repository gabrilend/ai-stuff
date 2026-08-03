# backwards-reader — architecture

## What it is

A program that reads a piece of text against its own grain, at several
sizes at once, and sets each turned-around version beside the original so
the two can be compared.

The vision asks for three things:

1. process a block of text one line at a time, then run it in reverse
2. break it into sentences — a sentence being a self-contained idea — and
   reverse those
3. read each sentence in *backwards meaning*, so that
   *"leading her down the storyway, the right wind messed with her jairs"*
   comes back as
   *"there was little to say, the jester led her astray"*

and then names the failure mode of doing this forever: `[stack overflow]`.

Those three are not three features. They are one operation at three
magnifications, which is what the whole design is built around. See
`strategems/reversal-is-scale-free.md` for the pattern stated in general.

## The ladder

Text has seams at many sizes. At each size there is a whole, a way to find
its pieces, a way to turn the pieces around, and a way to put them back.
That quadruple is a **rung**. The rungs stack into a ladder, and a reading
is a descent down it and a climb back up.

| Rung | Whole | Pieces | What "turned around" means | Needs a model |
|---|---|---|---|---|
| 0 | document | blocks | emit blocks last-first | no |
| 1 | block | lines | emit lines last-first | no |
| 2 | line group | sentences | emit sentences last-first | no, to split; yes, to split *well* |
| 3 | sentence | clauses | emit clauses last-first | no, to split; yes, to split *well* |
| 4 | clause | its meaning | say the opposite thing | yes |
| 5 | word | its sense | antonym, or the sound run backwards | partly |
| 6 | — | — | `[stack overflow]` | — |

Rung 4 is the one the vision's worked example is really about, and reading
that example closely is what fixed the design. Look at what happened:

    leading her down the storyway,  |  the right wind messed with her jairs
    the jester led her astray       |  there was little to say
                                    ^
                        the clauses also swapped sides

The meaning of each clause was inverted **and** the clauses changed places.
Two different rungs fired in the same breath — rung 3 reordering, rung 4
inverting. That is the evidence that the rungs are genuinely the same
mechanism at different sizes rather than a metaphor: they compose without
knowing about each other.

### Where the ladder stops

`[stack overflow]` is a joke and also the real design problem. A scale-free
pattern will not find its own floor. This program supplies one from
outside, explicitly:

- a **depth budget**, a plain integer, set per reading
- descending past it is an **error**, not a truncation

It does not silently stop and return what it had. A reading that hit its
floor and pretended otherwise would produce a mirror that looks finished
and is not, and no downstream measurement could tell the difference. Loud
failure is the only honest option, and it matches the house rule: prefer a
break to a fallback.

## The two halves, which never touch

Generation and viewing are separate programs sharing only a file format.

**Generation** takes text and produces a *reading*: an append-only,
checksum-chained record of every unit the descent touched, its mirror, and
the measurements taken. It renders nothing.

**Viewing** takes a reading and shows it. It calls no model, reaches no
door, and cannot change what it displays.

The seam between them is the record file. This is worth the discipline: a
reading is expensive (it is thousands of small inferences) and viewing it
is free, so they must be separately runnable or every change to the
presentation costs another cluster run.

## The contrast is the product

The mirror on its own is close to worthless, and the vision says so —
*"which doesn't really much mean, alone as a sentence"*. What has value is
the **pair**, and the distance between its halves.

So every unit in the record carries three things: what it said, what its
mirror said, and the **angle** between them — the cosine distance between
the two embedding vectors, taken from the same model family that produced
the mirror.

The angle is the measuring instrument. It answers a question a person
otherwise has to answer by hand, thousands of times per reading:

- **angle near zero** — the model paraphrased instead of inverting. The
  mirror failed and the pair is noise.
- **angle near maximum** — the model wandered off. The mirror is unrelated
  to the original rather than opposed to it. Also noise, from the other
  side.
- **angle in the band between** — the mirror is *about* the same thing and
  *says the other thing*. This is the one worth showing a person.

Choosing the band is an empirical question, not a constant to guess, so it
is measured rather than declared — see `docs/datapath-the-angle.md`.

This is the "measurement equipment" idea from the house notes made literal:
a second kind of processor whose job is not to compute the answer but to
detect waves in dataforms by measuring angles of similarity.

## The doors

A reading is thousands of independent small inferences: one short input,
one short output, no shared state between units. There is no workload that
wants a cluster more than this one, and none where distribution is easier —
nothing has to be kept coherent between machines.

A **door** is an address that answers. What is behind it is not this
program's business — one machine, three little minds, a model split across
a rack. The roster lives in `input/cluster`, one line per door, in the same
format the porch in `gif-generator` already uses, because two programs on
one network should not disagree about how to name machines.

Work is routed by **price**. Each door quotes a price for taking one more
unit, computed from what that door has actually been observed to do and how
much is already waiting on it. Cheapest door wins. Prices equalize
pressure; a door that slows down gets expensive and stops receiving work
without anyone being told. The rule is stated in full in
`strategems/price-as-a-load-balancer.md`.

**This machine is a door too**, with a price computed the same way. That is
the part worth pointing at. The crossover — the point where sending a piece
of work away costs more than doing it here — is not a constant somebody
tuned once. It falls out of the price comparison, per unit, continuously,
and cannot go stale. A separate measuring utility exists to plot where that
crossover currently sits, because knowing the shape of that curve is one of
the things this project is actually for.

## Concurrency

LuaJIT coroutines over a shared task stack, one coroutine per in-flight
unit, with the socket reads yielding. A thread pool is a distributed
resolving of a stack of coroutines; that is the model used here literally
rather than by analogy.

The parallelism that matters is not CPU parallelism — the work is almost
entirely waiting on a door to answer. Hundreds of coroutines can be in
flight against five doors on one OS thread, and the limit is door capacity,
not scheduler capacity. `effil` is available in the shared library shelf if
real OS threads are ever needed for the mechanical rungs, which are the
only CPU-bound part; they are not needed yet, and adding them before a
measurement says so would be guessing.

## Language and dependencies

LuaJIT 2.1. Three dependencies, all already on the shelf at
`/home/ritz/programming/ai-stuff/libs/lua/`:

| What | Why | Where |
|---|---|---|
| `dkjson.lua` | llama.cpp speaks JSON | shared shelf |
| `luasocket` | HTTP to the doors | shared shelf |
| `effil-jit` | real threads, if ever needed | shared shelf, unused today |

No model runtime is vendored. llama.cpp is reached over HTTP, which is what
makes a door a door — the program cannot tell a local `llama-server` from
one three rooms away, and should not be able to.

## Testability

Every part that talks to a model takes its **transport as an argument**: a
plain function from request to reply text. Tests hand in a fake. This is
the same pattern the porch in `gif-generator` uses, and it means the entire
program above the socket is testable on a machine with no GPU, no cluster,
and no model file — which is the machine it was written on.

The real llama.cpp adapter is one small module that satisfies the same
function signature. It is the only part that cannot be tested without
hardware, and it is deliberately the smallest part.

## Source order

Source files are numbered so the project reads front to back as one story,
counting up across directories rather than within them. Each module is
followed by the test that proves it. The current map is generated rather
than maintained by hand — run `scripts/source-order.sh`.

## Related documents

- `docs/datapath-the-ladder.md` — how text becomes rungs and back
- `docs/datapath-the-record.md` — the append-only reading format
- `docs/datapath-the-doors.md` — roster, price, dispatch, crossover
- `docs/datapath-the-angle.md` — embeddings and the contrast band
- `docs/roadmap.md` — the phases
- `notes/vision` — the original ask, unedited
