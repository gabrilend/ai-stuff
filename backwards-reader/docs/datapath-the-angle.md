# datapath — the angle

The instrument that decides whether a mirror worked, without asking a
person.

## Why an instrument is needed at all

A reading of a page produces hundreds of pairs. Most will be bad — the
model paraphrased, or wandered, or produced something fluent and unrelated.
Handing a person hundreds of pairs and asking them to find the few good
ones is handing them the work back.

So the program measures each pair and sorts by the measurement. The person
reads the top of the list.

## What is measured

An **embedding** is a fixed-length list of numbers a model produces for a
piece of text, positioned so that texts meaning similar things land near
each other. `llama-server` returns one from `/embedding`: a flat array of
floats, typically 384 to 1024 of them depending on the model.

Two embeddings are compared by **cosine distance**:

    similarity = dot(a, b) / (magnitude(a) * magnitude(b))
    distance   = 1 - similarity

Both vectors are normalized to unit length first, which reduces the
similarity to a plain dot product and makes the whole measurement one loop
over a couple of hundred floats. On a page of text this is thousands of
tiny loops and costs nothing next to the inference that produced the
mirrors.

`distance` runs 0.0 (identical direction) to 2.0 (opposite direction), and
in practice sits between 0.0 and about 1.0 for text from one language.

## Reading the number

| Distance | What happened | Worth showing |
|---|---|---|
| ~0.0–0.15 | the model restated the original in other words | no — it did not invert |
| ~0.15–0.55 | about the same subject, saying the other thing | **yes** — this is the band |
| ~0.55+ | unrelated to the original | no — it wandered off |

The band edges above are a starting guess and are written here as a guess
on purpose. They depend on the embedding model, the length of the units,
and the language, and a number guessed once and hard-coded becomes a lie
the first time the model changes. So:

- the band is **calibrated**, by a utility that runs a set of known-good
  and known-bad pairs through the current model and reports where they
  actually land
- the calibration writes to `input/band`, which the reader loads at startup
- a reading whose `input/band` is missing runs anyway and records raw
  distances, but **refuses to sort or filter by them**, and says so

That last point is the honest failure. Without calibration the numbers are
still real measurements, they simply have no known meaning yet, and the
program must not pretend otherwise by ranking on them.

## The second axis, which does not exist yet

Distance can tell "far" from "near". It cannot tell "far in the right
direction" from "far because it became nonsense" — both land in the same
place, and that is the instrument's real limitation.

The intended second measurement is **involution**: mirror the mirror, and
see whether it comes back near the original. A true reversal is close to
its own inverse; nonsense is not, because nonsense has no opposite to
return along. This doubles the inference cost of a reading, which is
exactly the sort of thing a cluster is for.

It is written down in `desire/what-would-be-better.md` and is not built.
The angle datapath is designed so it can be added as a second field on the
unit rather than a change to anything existing.

## Where it runs

Embedding is a separate door kind (`angle`) because it is a different
model — small, fast, and not the one producing mirrors. A machine can serve
both, and `llama-server` can be started with an embedding model alongside a
generation one, which is why `both` exists in the roster.

Embeddings for a unit and its mirror are two independent requests and go
through the same price-routed pool as everything else. They are the
cheapest units in the system and are good early traffic for warming up a
door's `cost_ms` estimate before expensive mirror work is routed by it.

## Related

- `docs/datapath-the-doors.md` — how these requests get routed
- `docs/architecture.md` — why the contrast, not the mirror, is the product
- `desire/what-would-be-better.md` — the involution measurement
