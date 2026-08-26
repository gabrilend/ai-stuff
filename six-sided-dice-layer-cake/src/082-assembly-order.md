# 082 — The order it goes together in

```meta
phase  | 12
issues | 1202
```

## Why the order is not free

**Every bond in this machine is permanent.** Once a face is attached to the cage
nothing inside can be touched again — no probe, no rework, no replacement. So the
sequence is determined by one rule: **everything that can be tested must be tested
before the step that makes it unreachable.**

```drawing
the sequence, and the step that cannot be undone [not-dimensioned]

    1  memory tiers            tested at wafer, thinned, singulated
    2  the core stack          tiers and laminae bonded, tested every few
    3  the cage                bonded around it -- last reach to the core
    4  compute dies            tested at wafer, thinned
    5  face assemblies         dies, cold plates, regulators, port fields
                               ── tested completely; the largest thing that
                                  can still be discarded cheaply
   ═══════════════════════════════════════════════════════════════════
    6  faces onto the cage     ◀── THE POINT OF NO RETURN, six times
   ═══════════════════════════════════════════════════════════════════
    7  rails and corners       sealed
    8  pressure test           the only chance before power
    9  the spout's far side    if bonded; stakes a second object on the first
   10  final test              through whatever access survives
```

## The step that decides everything

**Step six.** Before it a bad face costs a face; after it a bad face costs a cube.

So step five's coverage has to be very close to complete, and `084` has to say
what fraction it actually reaches — because **the difference between ninety-five
and ninety-nine per cent coverage at step five is a large multiple in the cost of
a finished machine.**

## The temperature ladder

Each bonding step has a temperature and **every step must be cooler than the one
before**, or an earlier bond reflows while a later one is being made. With hybrid
bonds, solder, an elastomer seal and possibly a wafer-level bond at step nine, the
ladder is tight — and `066`'s bond against an already-assembled cube is the
sharpest case.

## And the cube ships empty

`021` established that water freezes and a cube may see minus twenty in transit.
So filling and purging is not an assembly step at all — it happens at
installation, and `085` owns it. Worth stating here because the natural place to
look for it is this list.

## Symbols

```symbols
n_step_assy   | 1 | given | 10       | steps in the sequence
n_gate        | 1 | given | 6        | test gates: after tiers, the stack, the cage, dies, face assemblies, and final
step_no_return | 1 | given | 6       | the step after which a defect costs a cube rather than a part
T_bond_tier   | K | given | 573.0    | temperature the tier-to-lamina bonds are made at, step two
T_bond_cage   | K | given | 553.0    | the cage to the core, step three
T_solder_face | K | given | 523.0    | microbumps and regulators on a face, step five
T_bond_face   | K | given | 503.0    | faces onto the cage, step six
T_seal        | K | given | 423.0    | curing the edge seals, step seven
f_cover_five  | 1 | given | 0.985    | share of defects a face assembly test finds, which 083 uses and 084 must actually deliver

n_step_before | 1 | derived | step_no_return - 1        | steps whose output can still be discarded cheaply
n_step_after  | 1 | derived | n_step_assy - step_no_return | steps at which a defect scraps a whole cube
f_value_risk  | 1 | derived | n_step_after / n_step_assy | share of the sequence spent past the point of no return
T_ladder_ok   | 1 | derived | 1                          | whether the bonding temperatures decrease monotonically; the constraints below are what establish it
```

## Constraints

```constraints
C-082-1 | T_bond_tier > T_bond_cage      | the ladder, step two above step three
C-082-2 | T_bond_cage > T_solder_face    | step three above step five
C-082-3 | T_solder_face > T_bond_face    | step five above step six
C-082-4 | T_bond_face > T_seal           | and step six above step seven. Four constraints on five temperatures that are obviously in the right order, which is exactly the situation where inserting a step breaks it quietly
C-082-5 | T_bond < T_bond_face           | and the spout's bond at step nine must be cooler than everything already inside, which is the sharpest case in the ladder because by then the whole cube is assembled
C-082-6 | n_gate >= step_no_return       | there must be a test gate at or before every step that makes something unreachable
C-082-7 | f_cover_five >= f_cover_needed | the face assembly test must find at least the fraction 083's yield model assumes, which is the number the finished cost turns on
```

## What is still open

**Step nine's ladder position is uncomfortable.** `066` bonds at a temperature
that must be below everything already in the cube, which is the tightest
constraint in the ladder — and `068`'s byte mode, attached with ordinary
microbumps, sidesteps it entirely. That is another argument for byte mode that
`068` does not make.

**Nothing says how long the sequence takes**, and step two alone is twenty-four
bonds each with a dwell.
