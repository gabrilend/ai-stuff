# 084 — Reaching a die that is sealed inside a cube

```meta
phase  | 12
issues | 1204
```

## The three stages

**Before assembly.** Ordinary probing on pads. Full coverage, cheap, and where
nearly every defect must be caught because `082` says everything after step six
costs a cube.

**During assembly.** After each of `082`'s gates. Partial access — a stack of
tiers can still be probed on its top surface, a face assembly still has its port
field exposed.

**After sealing.** No probes, no pads, no access except through six outward port
fields. **Everything inside is reachable only by something inside talking
outward.**

## The mechanism, and its two unusual requirements

A scan chain threaded through every die, reachable from any port field.

**It must not depend on what it tests.** The chain runs from a port field through
a face and across five million connections to the cage. If those bonds are what is
being tested, the chain that tests them cannot use them — so there is a separate,
small, robust path, and `C-084-1` says so.

**It must work when the machine will not boot.** `073` gives every step a fault
bit, but a cube that fails at step three cannot report through anything step four
brings up. The chain is alive as soon as the auxiliary domain is, which `033`
powers first.

## The coverage figure that decides the cost

`082`'s step five and `083`'s yield model both need one number: **what fraction of
defects a face assembly test actually finds.** The gap between that and one is the
fraction of cubes that fail after the point of no return, and it is probably the
largest single cost driver in the machine.

## What cannot be tested, and is admitted

Marginal timing at the slow corner. Thermal behaviour under a real power map.
Coolant flow distribution. Anything that wears. **Listing them is the point** — a
test blueprint that implies complete coverage is worse than one that says where
it stops.

## Symbols

```symbols
n_scan_chain  | 1 | given | 8         | independent scan chains, so a whole cube is not one serial path
f_scan_rate   | MHz | given | 50.0    | rate the chains shift at
n_scan_cell   | 1 | given | 2.4e6     | scan cells in one cube
n_pattern     | 1 | given | 4000      | patterns in the production test
f_cover_scan  | 1 | given | 0.985     | share of defects the sealed-cube scan test finds
f_cover_probe | 1 | given | 0.995     | share a probe test before assembly finds
n_untestable  | 1 | given | 4         | properties named as untestable by this blueprint

t_scan_shift  | s | derived | n_scan_cell / n_scan_chain / f_scan_rate | one full shift through the longest chain
t_test_prod   | s | derived | t_scan_shift * n_pattern * 2                     | production test time, shifting in and out for every pattern
n_aux_only    | 1 | given | 1         | separate access paths that run on the auxiliary domain alone and share nothing with the interface they test
f_cover_five_d | 1 | derived | f_cover_probe                                  | coverage at 082's step five, which is a probe test on an unsealed face assembly
t_test_budget | s | given | 60.0      | the most production test may take per cube
```

## Constraints

```constraints
C-084-1 | n_aux_only >= 1              | there must be at least one access path that does not depend on the interface it is used to test, and that runs on the auxiliary domain before anything else is up. Two requirements in one count, because the notation cannot express either directly -- and both are the difference between diagnosing a dead cube and discarding it
C-084-2 | t_test_prod < t_test_budget  | production test must fit its budget. A chain through sixty-one dice is long, and this is the constraint that decides how many chains there are
C-084-3 | f_cover_five_d >= f_cover_needed | the coverage at the last gate before the point of no return must reach what 083's yield model assumes
C-084-4 | f_cover_probe > f_cover_scan | probing before assembly must find more than scanning a sealed cube. Trivially true and worth asserting, because it is the reason 082's gates are placed where they are rather than relying on a final test
C-084-5 | n_untestable >= 4            | at least four properties must be named as untestable. Asserted in the direction of honesty: a test blueprint that implies complete coverage is worse than one that says where it stops
C-084-6 | n_scan_chain > 1             | more than one chain, or a single broken cell makes a whole cube untestable
```

## What is still open

**The spout is not covered.** `066` needs to know which of sixteen million bonds
failed so that `063`'s remap can act, and the only opportunity is after the bond,
when the object cannot be taken apart. Nothing here reaches it.

**The coverage figures are `given`.** Ninety-eight and a half per cent and
ninety-nine and a half are plausible and unsourced, and `083`'s whole cost model
turns on the second of them.

**Nothing tests the coolant path.** It is named as untestable, which is true of
its behaviour under load and false of its integrity — `082`'s pressure test exists
and is not counted here.
