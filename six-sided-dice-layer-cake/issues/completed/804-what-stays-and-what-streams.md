# 804 — What stays, and what streams

Produces `src/059-residency-and-paging.md`.

## Current behavior

**Done.** `src/059-residency-and-paging.md` exists with the three tiers, the
cliff, and refusal chosen over degradation — with a shorter context offered as
the graceful alternative, because a machine that thinks in shorter breaths beats
one that refuses to start.

The slice policy is the interesting half: **a cache with no cache logic.** No
tags, no comparators, no victim selection, because the walk order is known before
the token starts and there is nothing to choose between. `C-059-6` asserts the
absence as a value so that a blueprint adding a policy has to say what it is
choosing between.

Six constraints, all holding.

**`C-059-4` is a tautology and the blueprint says so.** The refusal threshold has
no independent expression, so nothing can check that an implementation uses the
capacity rather than a rounded version of it — and writing a second symbol to
compare against would have created exactly the drift the constraint exists to
prevent. It is a marker for a reader, not a check.

**Streaming is priced and not designed.**

## Intended behavior

**The residency policy: what lives in the core, what lives in a face slice, what
streams from the media, and what happens when a model does not fit.**

### The three tiers

| tier | size | read rate | how often a weight is read from it |
|---|---|---|---|
| face slice | 922 MB | full engine rate | once per sequence in the batch |
| core | 64 GiB | 39 TB/s | once per token |
| media | unbounded | 1.28 TB/s | never, after load |

The ratios between the rows are what the policy is made of. Core to media is about
**thirty to one**, and that single number is the whole cliff: a model that fits in
the core runs at core speed, and a model that does not runs, for the part that does
not, at media speed.

### Where the cliff is

The blueprint must state it exactly rather than qualitatively. Resident capacity
is sixty-four gibibytes; the model needs its weights plus the key and value cache
at the intended context and batch, both from `1104`. **The cliff is where those
sum past capacity**, and the blueprint should give the surface — a table of model
size against context length against batch, with the boundary drawn on it.

### What happens past it

Three options and the blueprint must choose:

**Refuse.** The machine declines to load a model that does not fit. Clean, honest,
and turns a performance mystery into an error message at load time. This is the
recommended one and it matches the project's general preference for refusing over
degrading.

**Stream the overflow.** The layers that do not fit are read from media every
token. With thirty-to-one between the tiers, streaming a tenth of the model
roughly quadruples the time per token. The blueprint must give that curve, because
somebody will want it and should see its shape before they choose it.

**Shorten the context.** The key and value cache grows with context, so a machine
that cannot hold a full-length conversation can still hold a shorter one. **This
is the good degradation** and it should be offered, because a machine that thinks
in shorter breaths beats one that refuses to start.

### The slice policy

Smaller and simpler: a face slice holds the layer being computed and the layer
being fetched, and nothing else, ever. There is no replacement policy because
there is nothing to choose between — `608`'s walk order is known in advance and
`805` prefetches exactly the next layer. **This is a cache with no cache logic**,
which is worth saying because it is unusual and it is why the slice needs no tags
and no comparators, only two buffers and a pointer.

## Symbols this must publish

Capacity per tier. Rate per tier. Tier ratios. Resident requirement as a function
of model size, context length and batch. The fitting surface and its boundary.
Time per token when streaming a given fraction. Maximum context at a given model
size. Slice buffer count and the absence of replacement logic.

## Constraints this must assert

- Resident requirement at the reference model, reference context and reference
  batch is under usable capacity from `501`.
- Slice capacity is at least twice a layer's weights. Restated from `607`, because
  it belongs to the residency policy as much as to the memory.
- The refusal threshold equals the capacity, exactly — no silent rounding that
  lets a model half a gigabyte too large load and run badly.

## Suggested implementation steps

1. Build the resident requirement from `1104` as a function of three variables.
2. Draw the fitting surface and mark the boundary.
3. Choose refusal, and offer shortened context as the degradation.
4. Give the streaming curve anyway, so the choice is informed.
5. Write the paragraph about the slice having no cache logic.

## Blocks

`805`, `806`, `1104`.

## Blocked by

`501`, `607`, `802`, `1104`.

## Related documents

`000` for the cliff claim. `004` for the three legs.
