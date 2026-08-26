# 042 — Why a face is four dies

```meta
phase  | 6
issues | 602
```

## The constraint

A photolithography scanner exposes a field of about twenty-six by thirty-three
millimetres. Nothing larger can be printed in one exposure. A face wants to be
fifty-two millimetres square, which is more than three times the largest die that
can exist.

**This is not a design decision and the blueprint says so**, because treating it
as a choice invites somebody to revisit it. A face is a tile array; the only
remaining questions are how many tiles and how they are joined.

Two by two, twenty-four millimetres each, is what fits: five hundred and
seventy-six square millimetres, two thirds of a reticle field, leaving margin for
the scribe lane and for yield.

## What four dies have to pretend

**One radial link, not four.** `051`'s interface is per-face. Either one die
carries it and relays for the other three — asymmetric, and that die runs hotter
— or the link is split four ways and the cage treats four quarter-width ports as
one. **The split is chosen**: it costs the cage more logic and keeps the four dies
identical, and identical dies are what make `083`'s yield arithmetic tractable.

**One slice, not four.** The sequencer wants to address a face's slice as one
thing, so any access crossing a die boundary is inter-die traffic. The weights
are therefore partitioned so that **each die owns the rows of the weight matrix
its own multipliers consume**, which makes crossings rare rather than managed.

**Four sequencers in lockstep, not one.** Simpler than one sequencer driving four
dies over an inter-die link, and it costs four copies of a block that is under
three per cent of the die.

## Symbols

```symbols
w_reticle     | mm | measured | 26.0 | short side of a scanner's exposure field
h_reticle     | mm | measured | 33.0 | long side of the same
n_die_face    | 1  | given | 4       | compute dies on one face
w_scribe      | mm | given | 0.08    | scribe lane between two dies on a wafer
e_interdie    | pJ/bit | measured | 0.35 | energy to move one bit between two dies on the same face interposer
f_interdie    | 1  | given | 0.02    | share of a face's operand traffic that crosses a die boundary despite the partitioning

A_reticle     | mm^2  | derived | w_reticle * h_reticle          | area of one exposure field
f_reticle_use | 1     | derived | A_die / A_reticle              | how much of a field one die uses
B_interdie    | bit/s | derived | f_interdie * B_operand_die * n_die_face | traffic crossing die boundaries on one face
P_interdie    | W     | derived | e_interdie * B_interdie        | what that costs
w_link_split  | 1     | derived | n_die_face                     | how many ways the radial link is divided, one segment per die
n_die_total   | 1     | derived | n_die_face * n_face            | compute dies in the machine
```

## Constraints

```constraints
C-042-1 | A_die < A_reticle              | a die must fit in one exposure. The constraint that decided the tile count, and it is physics rather than preference
C-042-2 | f_reticle_use < 0.75           | and should leave a quarter of the field, because a die that fills its reticle has no room for the scribe lane and no tolerance for a stepper that drifts
C-042-3 | L_dieblock ~= n_die_face * L_die / 2 + w_street | the die block's edge from 012 must be what two dies and a street actually come to. Two routes to one dimension
C-042-4 | n_die_total == n_die           | the die count derived here must be the one 012 publishes
C-042-5 | P_interdie < P_die / 20        | traffic crossing die boundaries must cost under a twentieth of a die's power, or the partitioning in 075 is not keeping crossings rare and the four dies are not behaving as one face
C-042-6 | w_link_split == n_die_face     | the radial link is split one way per die, which is what makes the four dies identical
```

## What is still open

**The inter-die crossing fraction is a `given`.** Two per cent is what a
partitioning that works looks like; nothing has computed what `075`'s actual
assignment produces, and `C-042-5` is checking an assumption against a budget
rather than a design against a requirement.

**Four sequencers must agree at layer boundaries and nothing says how.** `048`
owns the mechanism and this blueprint only states that one is needed. If the
agreement costs a round trip across the interposer at every layer, thirteen
layers a token times a link crossing is not free.
