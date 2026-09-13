# 207 - The reachability probe

| | |
|---|---|
| Phase | 2 - the harvester |
| Blocked by | 201, 202 |
| Blocks | nothing, but prevents a class of wasted investigation |

## Current behaviour

The survey document states which sources answered, checked by hand on one day.
That claim is already ageing and nothing can refresh it.

## Intended behaviour

A program that asks every registered source for the smallest thing it can
answer, and prints what came back: the status, the shape, the size, and how long
it took.

This exists so that no document in the project has to be trusted about
reachability. The standing rule against baking statistics into documentation
applies directly - a document that says a source answers is stale the moment the
source stops, and a reader has no way to tell. A document that says "run the
probe" cannot go stale.

It is also the first thing to run when a harvest behaves strangely, and it
separates the two explanations that otherwise look identical from inside a long
harvest: the source changed, or our code broke.

## Suggested implementation steps

1. Each registry entry declares its smallest possible request - the cheapest
   thing that proves the source is alive. Probing must never be expensive for
   the server being probed.
2. Run them through the same scheduler as a real harvest, so that probing is
   subject to the same pacing rules and cannot itself become the rude thing.
3. Print a table, and exit non-zero if any source that was previously verified
   is now failing, so the probe can be run unattended and still be noticed.
4. Do not write probe results into the archive. A probe is a question about the
   present, not an observation worth keeping.
