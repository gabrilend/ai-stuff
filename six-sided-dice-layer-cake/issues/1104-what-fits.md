# 1104 — What fits

Produces `src/078-model-capacity.md`.

## Current behavior

Nothing. The reference model is used as an anchor in fifteen blueprints and is
defined in none of them.

## Intended behavior

**The reference model's shape, the residency arithmetic that follows from it, and
the surface separating what fits from what does not.**

### The reference model

Seventy billion parameters, eighty layers, hidden width eight thousand one hundred
and ninety-two, four-bit weights, thirty-five gigabytes. **Every capacity,
bandwidth and timing number in this project is anchored to it**, and `009` entry
B4 is the question of whether that is the right anchor.

The blueprint must state it as a set of symbols — layer count, hidden width, head
counts, feedforward width, vocabulary, context length — and derive the parameter
count from them rather than the other way round, so that a different model is a
different set of numbers and not a different document.

### Residency, in three terms

    resident  =  weights  +  key and value cache  +  working space

**Weights** scale with the model and not with anything else.

**Cache** scales with context length times batch size times layer count. It is the
term that turns capacity into a surface rather than a number, and at long context
it rivals the weights.

**Working space** is the staging buffers, the request region, the pane window, and
— if `1107`'s training is used — activation checkpoints and optimiser state.

### The surface, which is the deliverable

Three axes: model size, context length, batch size. Usable capacity is a plane
through them, and the blueprint's job is to draw the boundary and mark the
reference point on it with its margin.

Somebody deciding whether to buy one of these will look at exactly this figure and
nothing else, so it should be the clearest thing in the project.

### The cliff, stated exactly

`804` chose refusal over degradation. The threshold is this surface. The blueprint
must state it as an exact inequality — not a rule of thumb, not a recommended
maximum — because `804` requires the machine to refuse a model half a gigabyte too
large rather than load it and run badly.

### Sensitivity, because B4 is open

If the reference model is wrong, what moves? The blueprint must give the
derivatives: a layer twice as large doubles the slice requirement in `607`, which
does not fit, which means a larger die and a larger cube. A model twice as large
does not fit at all. **A model half as large would let the cube shrink**, and by
how much is a question `012` can answer and nobody has asked.

## Symbols this must publish

Model shape as symbols. Parameter count derived. Weight bytes at the chosen
format. Cache bytes per position per layer, and the total at reference context and
batch. Working space total. Resident total and margin against `501`. The fitting
surface. Sensitivity derivatives.

## Constraints this must assert

- Resident total at the reference point is under usable capacity from `501`.
- Largest layer times two is under `607`'s slice capacity. **The tightest
  constraint in the project**, restated here where the model shape lives.
- Weight bytes equal `1102`'s per-pass weight traffic.
- The refusal threshold equals usable capacity exactly.

## Suggested implementation steps

1. Define the shape as symbols and derive the parameter count.
2. Build the three residency terms.
3. Draw the surface and mark the reference point with its margin.
4. Produce the sensitivity derivatives, including the shrink case.

## Blocks

`501`, `607`, `803`, `804`, `1101`, `1102`, `1105`, `1106`, `1107`.

## Blocked by

`501`, `606`, `607`.

## Related documents

`000` for the cliff claim. `009` entry B4.
