# 070 — Where the beat comes from

```meta
phase  | 10
issues | 1001
```

## The domains

| domain | set by |
|---|---|
| face logic and engines | `074`'s critical path in the multiplier cell |
| core array | `035`'s access time |
| radial link | source-synchronous; `051` forwards its own |
| port field | whatever standard `057` adopts |
| auxiliary | slow, free-running, must tick when nothing else does |

## One reference or seven

**One.** Six faces have to agree what cycle it is (`072`), and six independent
references would drift apart — which is not a timing problem but an accounting
one: the shared timebase would stop being shared.

The cost is that a single path from outside the cube becomes a single point of
failure, so **losing the reference must be detected and must produce the same
response as a coolant fault**: the machine cannot be trusted to notice its own
clock has stopped.

## Where the multipliers sit

Per face, on the interposer, close to what they feed. Their jitter adds directly
to `074`'s budget, and their power is small — but **their supply sensitivity is
not**. A multiplier on a rail that droops under `031`'s load step shifts
frequency, which appears as jitter **exactly when the machine is busiest**. They
get their own filtered supply and the blueprint says why.

## Symbols

```symbols
f_ref         | MHz | given | 100.0  | the external crystal reference
jit_ref       | ps | given | 0.5     | cycle-to-cycle jitter of the reference
jit_mult      | ps | given | 3.0     | jitter one multiplier adds
psrr_mult     | 1 | given | 0.02     | fraction of a supply excursion that appears as a timing shift at the multiplier's output
t_lock_mult   | s | given | 3.0e-4   | how long a multiplier takes to settle from cold
n_ref         | 1 | given | 1        | references in the machine
P_clockgen    | W | given | 4.0      | all the multipliers together

ratio_face    | 1 | derived | f_face / f_ref               | multiplier ratio for the face domain
ratio_core    | 1 | derived | f_core / f_ref               | and for the core
jit_total     | ps | derived | sqrt(jit_ref^2 + jit_mult^2) | jitter at a multiplier's output, the two sources added in quadrature since they are independent
t_cycle_face  | ps | derived | 1 / f_face                   | the face cycle time everything in 074 is budgeted against
jit_supply    | ps | derived | psrr_mult * dV_droop_logic / V_logic * t_cycle_face | timing shift caused by the supply drooping under a load step, which arrives at the worst possible moment
jit_budget    | ps | derived | jit_total + jit_supply       | what 074 must allow for altogether
f_merge_gap   | 1 | derived | f_face / f_core              | how much faster the faces run than the core, which is the question of whether the two domains can be one
```

## Constraints

```constraints
C-070-1 | ratio_face == floor(ratio_face) | the face multiplier ratio must be a whole number, or the reference and the face clock have no common edge and 072's timebase cannot be derived from both
C-070-2 | jit_budget < t_cycle_face * 0.05 | jitter altogether must stay under a twentieth of a cycle, which is what 074's budget allocates to it
C-070-3 | jit_supply < jit_total          | supply-induced jitter must be smaller than the oscillator's own, or the filtered supply is not filtered. This is the term that appears exactly when the machine is busiest, so it is the one worth constraining separately
C-070-4 | n_ref == 1                      | one reference. Asserted as a value, because six would drift apart and 072's shared timebase would stop being shared
C-070-5 | t_lock_mult < t_powerup_max     | the multipliers must settle inside the power-up time 033 allows
C-070-6 | P_clockgen < P_load / 100       | generating the clock must cost under a hundredth of the machine
```

## What is still open

**Whether the face and core domains can be one.** `f_merge_gap` is published for
exactly this question and `074` has to answer it: closing `035`'s path at the
face clock would remove a domain and a crossing, and nobody has said whether it
can be done.

**Reference loss is required to be detected and no detector is specified.** The
constraint says the response must match a coolant fault; what watches, and how
fast, is not written, and it cannot be anything clocked by the thing it is
watching.
