# 075 — Cutting the model into six

```meta
phase  | 11
issues | 1101
```

## The constraint the cut must satisfy

`053` says the slowest stage sets the rate and every other face waits. So the cut
must **balance time, not layer count** — and the two differ, because face zero
also does the embedding lookup and face five also does the output projection.

The output projection is the awkward one: it is larger than any transformer layer
and it is read once per token like everything else.

## The rule

Below the crossover the machine is bandwidth-bound, so the currency is **bytes
read per stage**. Assign layers so that the bytes each face reads per token are as
equal as possible, with the embedding and the projection counted at their real
size.

```drawing
the assignment, by bytes rather than by count [not-dimensioned]

   face 0   embedding  + twelve layers    ─┐
   face 1                fourteen layers   │  every face reads
   face 2                fourteen layers   │  within a few per cent
   face 3                fourteen layers   │  of the same number
   face 4                fourteen layers   │  of bytes per token
   face 5   projection + twelve layers    ─┘
```

Above the crossover the currency becomes arithmetic rather than bytes. For this
model the two orderings agree, because both scale with parameter count — but they
would not for a model whose layers differed in shape, and the blueprint says so.

## What else the cut must respect

**Slice capacity.** `047` requires a face to hold what it is computing and what
it is fetching. For faces zero and five that is the projection plus a layer, which
is the binding case and is `078`'s `C-078-2`.

**Contiguity.** A face's layers must be consecutive, or the handoff stops being a
simple pipeline and `058`'s media layout stops being six contiguous regions.

## Symbols

```symbols
n_layer_end   | 1 | given | 12       | transformer layers on face zero and on face five, which also carry the embedding and the projection
n_layer_mid   | 1 | given | 14       | layers on each of the four faces between them

n_layer_face  | 1 | derived | n_layer_mid                            | layers on the busiest face by count, which 048 sizes its chains against
n_layer_check | 1 | derived | 2 * n_layer_end + 4 * n_layer_mid      | layers assigned altogether, which must be the model's
C_face_end    | MB | derived | C_layer_max + n_layer_end * C_layer_weights | bytes face zero or face five reads per token
C_face_mid    | MB | derived | n_layer_mid * C_layer_weights          | and one of the middle four
C_face_mean   | MB | derived | C_weights / n_face                      | what an evenly cut face would read
C_face_worst  | MB | derived | max(C_face_end, C_face_mid)             | the slowest stage, which sets the rate
f_imbalance   | 1 | derived | (C_face_worst - C_face_mean) / C_face_mean | how far the slowest stage is above the mean, which is what 053 tolerates
f_imbalance_c | 1 | derived | (max(n_layer_end, n_layer_mid) - n_layer / n_face) / (n_layer / n_face) | what the imbalance would have been had the cut been made by layer count instead, which is the comparison that justifies balancing by bytes
```

## Constraints

```constraints
C-075-1 | n_layer_check == n_layer     | every layer must be assigned to exactly one face
C-075-2 | f_imbalance < tol_stage      | the slowest stage must be within 053's tolerance of the mean, or the pipeline runs at its speed and the other five faces wait
C-075-3 | f_imbalance < f_imbalance_c  | balancing by bytes must beat balancing by layer count. Asserted because it is the whole reason this blueprint is not a division by six, and because for a model with uniform layers it would be false -- which is exactly when somebody would simplify it away
C-075-4 | n_layer_end < n_layer_mid    | the two faces carrying the embedding and the projection take fewer layers, which is the cut doing what it is for
C-075-5 | C_layer_max < C_face_slice / 2 | the largest single thing a face holds -- the output projection -- must leave room for another beside it. Written first as the face's whole share against its slice, which compares a token's worth of reading against a buffer and is not a thing that has to fit
```

## What is still open

**The rule is stated and the algorithm is not.** The blueprint gives an
assignment for this model and the rule that produced it. Given a different shape,
somebody must apply the rule by hand — and `058`'s media layout and `048`'s
chains both depend on the answer.

**Above the crossover the currency changes and nothing checks it.** For this model
bytes and arithmetic scale together, so one assignment serves both. For a model
whose layers differ in shape they would not, and there is no second assignment.
