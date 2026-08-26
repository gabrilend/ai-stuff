# 050 — Six spokes and no rim

```meta
phase  | 7
issues | 701
```

A short blueprint whose whole job is to justify an absence.

```drawing
the interconnect, entire [not-dimensioned]

              face 1
                 │
     face 4 ─────┼───── face 2
                 │
           ┌─────┴─────┐
     ──────┤  the cage ├──────  face 3
           └─────┬─────┘
                 │
     face 0 ─────┼───── face 5

   six edges. there is no path between two faces
   that does not pass through the middle
```

## The absence

There is no wire between any two faces. Everything one face sends another goes
into the core and comes out of it.

**Length.** A face-to-face wire runs around the outside of the cube or diagonally
across a cavity full of coolant and memory. Adjacent faces are a cube edge apart;
opposite faces are twice that. A face-to-core link is one face thickness. **A
seven millimetre link and a hundred and twenty millimetre link are different
technologies**, not the same one at different lengths — the long one needs
equalisation, retiming and far more energy a bit.

**Uniformity.** Fifteen face pairs at two distinct distances would mean two link
designs and fifteen timing closures. Six identical radial links mean one design
and one closure, which is the property `000` claims as a reason for the cube's
shape and this is where it is cashed.

**It is not needed.** The sieve's traffic is stage to stage, and that handoff is
sixteen kibibytes against six gigabytes of weight traffic. Building a mesh to
carry four parts in a million is not a trade, it is a mistake.

## What the absence costs, and what it does not

**Tensor parallelism is impossible.** Splitting one layer across several faces
needs an all-reduce between them every layer, which is exactly the traffic this
topology refuses. So the model is cut by layer and only by layer, which is
`075`'s constraint.

**Backpropagation is not foreclosed**, and this correction matters because the
opposite was assumed for a while. Cutting a model by layer is pipeline
parallelism, and a backward pass moves gradients from stage *n+1* to stage *n* —
the same handoff in the other direction, needing a second set of staging buffers
and nothing else from the interconnect. The all-reduce that training is usually
said to require belongs to data parallelism across replicas and to tensor
parallelism inside a layer, and this machine does neither.

What limits training here is **memory, not topology**, and it is `076a`'s subject.

## Symbols

```symbols
n_link         | 1 | derived | n_face                      | radial links, one per face
L_link         | mm | derived | t_face                     | length of one, face to cage
L_face_adj     | mm | derived | L_cube                     | the wire an adjacent-face link would have needed
L_face_opp     | mm | derived | 2 * L_cube                 | and an opposite-face one
n_pair         | 1 | derived | n_face * (n_face - 1) / 2   | face pairs a mesh would have had to connect
n_closure      | 1 | derived | 2                           | distinct link designs a mesh would have needed, one per distance
ratio_reach    | 1 | derived | L_face_opp / L_link         | how much further a face-to-face wire would have had to reach
f_handoff      | 1 | derived | C_handoff / (C_weights / n_face) | that as a share of the weight traffic one stage moves, which is the number that says a mesh would be carrying nothing
```

## Constraints

```constraints
C-050-1 | n_link == n_face             | one link per face, and none between faces
C-050-2 | ratio_reach > 10             | a face-to-face wire would have had to reach an order of magnitude further than a radial one, which is what makes them different technologies rather than the same one longer
C-050-3 | f_handoff < 0.001            | what crosses between two stages must be under a thousandth of what one stage reads. This is the justification for having no mesh, expressed as arithmetic that would notice if a model shape ever made the handoff significant
C-050-4 | n_pair > n_link              | a mesh would have been more connections than a star, which is trivially true and is here because the star's whole argument is that the extra ones would carry nothing
C-050-5 | L_link ~= t_face             | a radial link is exactly one face thickness, which is what makes all six identical and is the property that would break if the cage ever moved off centre
```

## What is still open

**Nothing here is a decision that could be revisited cheaply.** Adding a rim
later means adding a second link technology, a second timing closure and a route
through either the coolant or the memory. If tensor parallelism or data
parallelism is ever wanted, this is the blueprint that has to change first and it
changes everything downstream of it.
