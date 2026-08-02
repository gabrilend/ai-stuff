# 061, 062 — the thinking loop, and its stoppers — info

`061` is the machine's heartbeat: text becomes tokens, tokens run through
the assembly engine, a token is drawn and joins the input, repeat. `062`
closes the loop over the fixture model and exercises each of the four
stoppers by name.

## Running it

```
luajit src/062-test-thinking-loop.lua
```

## What `061` exports

| Name | Meaning |
|---|---|
| `new(options)` | a machine: model, kernels, the three declared modules (056, 057, 059), tokenizer tables, the carried numbers, settings, an optional finish token and boot atoms |
| `think(loop, request, limits)` | one turn: the request joins the context, the machine speaks until something stops it |
| `encode(loop, text)`, `decode(loop, numbers)` | the loop's edges, through the assembly tokenizer |

`think` returns text, tokens, position, and a `reason` naming what stopped
it: `"finished"` (the finish token, swallowed), `"length"`, `"interrupted"`
(a caller's function, asked between tokens — a machine that cannot be
interrupted mid-thought cannot be told to stop doing something), or
`"the room ran out"`.

## What the machine thinks with is the atom context

The loop reads the context (052) whole, lays it into the cache, and puts
what it says back as an atom — nothing said or heard sits outside the
enumerable list. What to let go of when the room runs out is the machine's
own decision through the context operations, never this loop's policy.

## The cache is reused, not recomputed

The loop keeps the token list the cache was built from; a re-read of the
context replays only what changed past the common prefix. `062` proves both
halves: a second thought costs only its new tokens, and the reused cache's
scores equal a fresh replay of the whole conversation, bit for bit.

## The defect integration found

The context used to join atoms with a newline — exactly the "separator
nobody named" its own test warned about. Those bytes belonged to no atom,
drifted the token accounting from the real encoding, and broke the cache's
prefix reuse at every atom boundary. Atoms now join with nothing between;
an atom that wants a boundary owns the boundary in its content. The rule in
`docs/013` was right all along; the implementation strayed and the loop
caught it.

## Two refusals at the seams

A byte the vocabulary cannot say is refused by position. A tokenizer table
that can say more tokens than the weights know is refused in words — a
broken image, said plainly, rather than an embedding read past its edge.

## The seams left open

Writing an atom out and recalling it waits for storage (`304`); loading the
boot set from the image waits for the builder (`502`). Hosted callers hand
boot atoms in directly.

## Result on 2026-08-02

13 of 13, and the context mechanism's own 17 of 17 still holding after the
separator fix.
