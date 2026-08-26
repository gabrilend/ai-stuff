# 401 — The power budget

Produces `src/028-power-budget.md`.

## Current behavior

**Done.** `src/028-power-budget.md` exists. Not one ampere in it is a `given` —
every current is a power from `020` divided by a voltage from `029`, so changing
the multiplier's switching energy moves the heat and the current together with
nobody editing either.

Six constraints. The reconciliation between this budget and `020`'s heat budget
is the one no single document can perform against itself, and what it exists to
catch is a mechanism counted in both.

The one asserted in the direction of alarm never fails and is worth having: at
the transistor's own voltage this machine would draw over a kiloampere, which is
what makes the two-stage conversion structural rather than an efficiency measure.

**Peak current is not distinguished from average.** `031` needs the step and
takes it from `045` rather than from here, which means the two can drift. And
nobody has checked the spout's burst on the port rail — over a hundred amperes
for thirty-three microseconds, fourteen times that rail's average.

## Intended behavior

**Current and power at every node of the delivery tree, at each of `301`'s three
operating points**, from the forty-eight volt input down to the last regulator.

The heat budget answers *how much energy leaves*. This answers *how much current
arrives, at what voltage, through what*. They are the same energy counted twice and
the value of writing both is that they must reconcile, which is a constraint no
single document can check against itself.

### The tree

```
   48 V, 40 A                     input, six-way, one per face
      │
      ├─ face 0 .. face 5         6.6 A each
      │     │
      │     ├─ 48→5 V stage       96 % efficient, on the interposer
      │     │     │
      │     │     ├─ V_logic  0.75 V   307 A per face   own dies
      │     │     ├─ V_array  0.85 V    31 A per face   own slice
      │     │     ├─ V_link   0.60 V    20 A per face   own link
      │     │     └─ inward share of the core            51 A per face
      │     │
      │     └─ V_port 1.20 V, V_aux 3.30 V
      │
      └─ the core and the cage    306 A total, arriving radially from all six
```

**The core is fed by all six faces at once**, one sixth each, which makes its
supply six-way redundant by construction: a face that loses a regulator stops
computing and the core keeps running on the other five. This is a real reliability
property and it should be stated as one, not left as an artefact of the topology.

### What must be derived rather than entered

Every current is a power from `301` divided by a voltage from `402`. Not one
ampere figure in this blueprint should be a `given`. That is what keeps the two
budgets locked together: change the matrix engine's switching energy and both the
heat and the current move, in step, automatically.

## Symbols this must publish

Current at every node of the tree, at all three operating points. Conversion
losses per stage. Input power and input current. Per-face and per-die totals. Peak
transient current and its slew rate, which `404` needs.

## Constraints this must assert

- **Input power equals total heat from `301`, exactly.** The reconciliation.
- Sum of the six faces' inward contributions equals the core's draw.
- Every current equals its power over its voltage. Trivial and worth having: it
  catches a voltage assigned to the wrong domain.
- Peak per-face current stays under what the port field in `801` can carry.

## Suggested implementation steps

1. Build the tree as a structure, not a table, so a node can be added without
   re-typing the arithmetic.
2. Derive every current from `301` and `402`.
3. Apply conversion efficiencies at the right nodes and check nothing is
   double-counted, which is the usual error and is what the reconciliation catches.
4. Produce all three operating points.
5. Compute peak slew and hand it to `404`.

## Blocks

`402`, `403`, `404`, `405`, `406`.

## Blocked by

`301`.

## Related documents

`006` for the whole path as a story.
