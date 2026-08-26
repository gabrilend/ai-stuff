# 086 — How long it lasts

```meta
phase  | 12
issues | 1206
```

## Why the target is set here rather than assumed

`032` sizes conductors against it. `040` sizes scrubbing against it. `072` sizes
synchronisers against it. `069` sizes a hash against it. **Four blueprints were
already deriving numbers from a target that did not exist**, which is exactly
backwards, and this fixes it.

## The nine mechanisms

| mechanism | owner |
|---|---|
| electromigration | `032` |
| bond fatigue | `018` |
| seal compression set | `017` |
| uncorrectable soft errors | `040` |
| synchroniser failure | `072` |
| undetected spout error | `069` |
| dielectric breakdown | here |
| coolant fouling and corrosion | `027` |
| pump wear | `027` |

They do not compose the same way. Some are wear-out and some are random, and
**adding them as though they were the same thing is the ordinary way to get this
wrong.** A machine whose random rate is fine and whose wear-out cliff is at three
years is not the same product as one with the reverse.

## The budget, and why it is uneven

Set the target, then divide it. Each mechanism gets an allocation and each owning
blueprint must meet its own — which turns *reliable* into nine checkable
constraints rather than one adjective.

**The allocation is deliberately uneven.** Mechanisms with no repair path deserve
the smallest allowance, and `019` establishes that nothing inside this cube has
one. The two outside — pump wear and fouling — take a much larger share because
they are serviceable, and that asymmetry is the whole reason to distinguish inside
from outside.

## The one that is not a hardware failure

A flipped weight bit that correction misses changes one number in one matrix and
the model produces slightly different text forever, with no symptom and no alarm.
`040` calls it out and `069` has the same shape at the output.

**It is treated as the worst mechanism on the list even though it breaks
nothing**, because the machine keeps running and lies. It gets the smallest
allocation of the nine.

## Symbols

```symbols
n_yr_target   | 1 | given | 10.0     | years a cube must run, continuously, replaced rather than repaired
t_year        | s | measured | 3.156e7 | seconds in a year, as a symbol rather than a literal because a literal here would be dimensionless
f_repl_annual | 1 | given | 0.05     | annual replacement rate tolerable in a population, which is what the target is chosen against
n_mech        | 1 | given | 9        | failure mechanisms
a_silent      | 1 | given | 0.02     | share of the failure budget allowed to silent corruption, the smallest of the nine
a_inside      | 1 | given | 0.38     | share allowed to everything inside the cube that has no repair path
a_outside     | 1 | given | 0.60     | share allowed to the pump and the fluid, which are serviceable
n_cyc_life    | 1 | derived | n_cyc_power | power cycles over the life, from 018

t_life_seconds | s | derived | n_yr_target * t_year          | the life, in the unit every other blueprint's mean-time figures are in
lam_target     | 1/s | derived | f_repl_annual / t_year      | failure rate the target implies
mtbf_target    | s | derived | 1 / lam_target                | and the mean time between failures it corresponds to
lam_silent     | 1/s | derived | lam_target * a_silent       | allocated to silent corruption
lam_inside     | 1/s | derived | lam_target * a_inside       | to everything unrepairable inside
lam_outside    | 1/s | derived | lam_target * a_outside      | to the serviceable loop
mtbf_silent    | s | derived | 1 / lam_silent               | the mean time between silent corruptions that 040 and 069 must together beat
a_sum          | 1 | derived | a_silent + a_inside + a_outside | the allocations, which must be the whole budget
ratio_asym     | 1 | derived | a_outside / a_inside         | how much more the serviceable half is allowed than the unrepairable half, which is the asymmetry 019's absence of repair justifies
n_cyc_check    | 1 | derived | n_yr_target * 365 * 27.4     | power cycles at a plausible rate over the life, for comparison against what 018 assumed
```

## Constraints

```constraints
C-086-1 | a_sum ~= 1                  | the allocations must be the whole budget, with nothing unassigned and nothing counted twice
C-086-2 | ratio_asym > 1              | the serviceable half must be allowed more than the unrepairable half. Asserted because it is the whole reason the budget is uneven, and a uniform split would be quietly wrong in the direction that matters
C-086-3 | t_double > t_life_seconds   | 040's mean time to an uncorrectable error must exceed the life
C-086-4 | mtbf_all > t_life_seconds   | and 072's synchronisers must
C-086-5 | t_undet_mean > mtbf_silent  | and 069's undetected spout errors must beat the silent-corruption allocation, which is the smallest of the nine because a machine that keeps running and lies is worse than one that stops
C-086-6 | n_cyc_check < n_cyc_life * 2 | the power cycles this life implies must be within a factor of two of what 018 assumed when it computed bond fatigue, or the fatigue analysis was done against the wrong count
C-086-7 | n_mech == 9                 | nine mechanisms. Asserted as a value so that a tenth arrives with an owner and an allocation rather than being folded into somebody else's
```

## What is still open

**Six of the nine have no derived number.** Electromigration, seal compression
set, dielectric breakdown, fouling and pump wear are named, allocated and not
computed. Three are — soft errors, synchronisers and spout corruption — and those
three are the ones with constraints above.

**Bond fatigue is the largest gap.** `018` counts three thermal swings and turns
none of them into cycles to failure, and this blueprint's allocation for it is a
number with nothing behind it.

**The target is a judgement.** Ten years continuous at a five per cent annual
replacement rate is chosen against a use case rather than derived, and the
blueprint says so. It is the right kind of number to have written down and argued
about.
