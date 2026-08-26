# 059 — What stays, and what streams

```meta
phase  | 8
issues | 804
```

## The three tiers

```drawing
where a weight can be, and how fast [not-dimensioned]

   face slice   ─── read once per sequence in the batch ─── full engine rate
        ▲
        │ once per token
        │
   the core     ─── read once per token ─────────────────── [B_core]
        ▲
        │ once per power cycle
        │
   the media    ─── read once, ever ──────────────────────── [B_feed]
```

The ratio between the middle and the bottom is what makes the cliff. Reading a
weight from the core is thirty times faster than reading it from a drive, so a
model that fits runs at core speed and a model that does not runs, for the part
that does not, at media speed.

## Where the cliff is, exactly

Resident capacity is what `034` says is usable. The model needs its weights plus
its key and value cache at the intended context and batch. **The cliff is where
those sum past capacity**, and it is a surface in three variables rather than a
number.

## What happens past it

**Refuse.** The machine declines to load a model that does not fit. Clean,
honest, and it turns a performance mystery into an error at load time — which
matches this project's general preference for refusing over degrading, and is
what `C-059-4` enforces by requiring the threshold to be the capacity exactly,
with no rounding that would let a model half a gigabyte too large load and run
badly.

**And offer a shorter context**, which is the good degradation. The cache grows
with context, so a machine that cannot hold a full-length conversation can still
hold a shorter one. A machine that thinks in shorter breaths beats one that
refuses to start.

The streaming curve is given anyway, so that the refusal is an informed choice
rather than a dogma.

## The slice policy

Smaller and simpler: a face slice holds the layer being computed and the layer
being fetched, and nothing else, ever.

**There is no replacement policy because there is nothing to choose between.**
`048`'s walk order is known before the token starts and `060` prefetches exactly
the next layer. This is a cache with no cache logic — no tags, no comparators, no
victim selection — which is unusual enough to be worth saying, because a reader
will assume the absence is an omission.

## Symbols

```symbols
ratio_core_media | 1 | derived | B_core / B_feed              | how much faster the core is than the media, which is the height of the cliff
C_resident       | GB | derived | C_weights + C_kv             | what a model needs resident: weights and cache together
f_resident       | 1 | derived | C_resident / C_core_usable   | how full the core is at the reference model, context and batch
C_headroom       | GB | derived | C_core_usable - C_resident   | what is left
n_ctx_max        | 1 | derived | n_ctx * (C_core_usable - C_weights) / C_kv | the longest context that would fit at the reference model and batch, which is the graceful degradation offered instead of streaming
f_stream_penalty | 1 | derived | ratio_core_media             | how much slower a streamed weight is than a resident one
t_token_stream10 | s | derived | t_token * (0.9 + 0.1 * ratio_core_media) | time per token if a tenth of the model had to stream, which is the curve a reader wants before choosing to allow it
n_slice_policy   | 1 | given | 0                              | replacement policies in the slice. There are none: the walk order is known in advance, so there is nothing to choose between
```

## Constraints

```constraints
C-059-1 | C_resident < C_core_usable    | the reference model at its reference context and batch must fit
C-059-2 | f_resident < 0.95             | and must leave a twentieth over, because a machine that fits its reference model exactly fits no other
C-059-3 | ratio_core_media > 10         | the core must be an order of magnitude faster than the media, which is what makes the cliff a cliff and streaming a bad idea rather than a slow one
C-059-4 | C_core_usable ~= C_core_usable | the refusal threshold is the usable capacity exactly, with no rounding. Written as a tautology deliberately: there is no separate threshold symbol to compare against, and inventing one would create the very gap this constraint exists to forbid
C-059-5 | n_ctx_max > n_ctx             | the shortest context the machine could offer as a degradation must be longer than the reference one, or the degradation is not available
C-059-6 | n_slice_policy == 0           | the slice has no replacement policy. Asserted as a value so that a blueprint adding one has to explain what it is choosing between
```

## What is still open

**`C-059-4` is a tautology and the blueprint says so.** The refusal threshold has
no independent expression, so nothing can check that an implementation uses the
capacity rather than a rounded version of it. Writing a second symbol to compare
against would have created exactly the drift the constraint is meant to prevent.
It is here as a marker for a reader rather than as a check.

**Streaming is priced and not designed.** The curve says what a tenth of the
model streaming would cost. Nothing says how the machine would decide which
tenth, where the streamed weights would land, or what would evict them.
