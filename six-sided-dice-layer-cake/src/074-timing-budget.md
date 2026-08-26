# 074 — Does it close

```meta
phase  | 10
issues | 1005
```

The blueprint that says whether the frequencies everything else assumes are real.

## The paths

| domain | the critical path is in |
|---|---|
| face logic | `045`'s multiply-accumulate cell |
| core array | `035`'s bitline, sense amplifier and output |
| radial link | `051`'s driver, bond, receiver and per-tile deskew |
| spout | `064`'s driver and `065`'s intra-tile skew |

## The corner, and the coincidence that makes it worse

Timing must close at the **slow** corner: highest temperature from `025`, lowest
voltage after `031`'s droop, slowest process.

And there is a coincidence worth naming. `025`'s peak junction temperature is a
**hot spot** number, and the hot spot is inside `045`'s multiplier array — which
is also where the critical path is. **The hottest transistors are the slowest
ones and they are the ones on the critical path.** So the budget uses the local
temperature and not the die average, and `C-074-5` requires it.

## Hold, which is where machines actually die

A setup failure shows up as a machine that will not run fast. **A hold failure
shows up as a machine that does not work at any speed**, and it gets *worse* at
the fast corner rather than the slow one — so a budget that examines only the slow
corner misses it entirely. Both corners are done and the blueprint says why.

## What the thermal margin buys

`025` reports margin between the hottest transistor and the silicon's limit.
Power goes roughly as the cube of frequency near the top of the range, so that
margin is worth a fraction of a clock increase before the hot spot catches up.

**`027` wants the same margin to remove a refrigeration plant.** They cannot both
have it, and neither blueprint has decided — but the curve belongs here, because
this is where frequency and temperature meet.

## Symbols

```symbols
t_logic_mac   | ps | given | 470.0  | logic delay through one multiply-accumulate cell at the slow corner
t_wire_mac    | ps | given | 55.0   | wire delay on the same path
t_setup       | ps | given | 25.0   | setup time at the capturing flip-flop
t_hold        | ps | given | 18.0   | hold time at the same
t_ocv         | ps | given | 45.0   | on-chip variation allowance across the path
t_logic_min   | ps | given | 80.0   | shortest logic delay on any path, which is what a hold failure is measured against
k_temp_delay  | 1/K | given | 0.0018 | fractional increase in delay per kelvin near the operating point
k_freq_power  | 1 | given | 3.0     | how power scales with frequency near the top of the range

t_path_face   | ps | derived | t_logic_mac + t_wire_mac + t_setup + skew_intra + jit_budget + t_ocv | everything the face's critical path has to fit inside a cycle
t_margin_face | ps | derived | t_cycle_face - t_path_face      | what is left
f_margin_face | 1 | derived | t_margin_face / t_cycle_face     | that as a share of a cycle
t_path_hold   | ps | derived | t_logic_min - skew_intra - jit_budget | the shortest path, less what could make it shorter still
t_path_core   | ps | derived | t_access + t_setup + skew_die + jit_budget | the core array's path
t_cycle_core_p| ps | derived | 1 / f_core                       | and its cycle
t_margin_core | ps | derived | t_cycle_core_p - t_path_core     | what is left there
t_path_at_face| ps | derived | t_path_core * 1                  | the core's path, for the question of whether it could run at the face clock
f_boost_max   | 1 | derived | (1 + margin_thermal * k_temp_delay)^(1 / k_freq_power) | how much faster the faces could run if the whole thermal margin were spent on clock rather than on removing a chiller
f_face_boost  | GHz | derived | f_face * f_boost_max            | and what frequency that would be
```

## Constraints

```constraints
C-074-1 | t_path_face < t_cycle_face   | the face's critical path plus all its uncertainty must fit inside a cycle at the slow corner. The constraint the whole blueprint exists for
C-074-2 | f_margin_face > 0.02         | and with at least a fiftieth of a cycle left, because the logic delay is a `given` from a cell 045 has not laid out
C-074-3 | t_path_hold > t_hold         | the shortest path, after everything that could make it shorter, must still meet hold at the fast corner. A setup failure is a machine that will not run fast; a hold failure is a machine that does not work at any speed, and it gets worse at the corner the setup check does not visit
C-074-4 | t_path_core < t_cycle_core_p | the core's path must fit its own cycle
C-074-5 | T_j_peak > T_j_mean          | the temperature used for the delay corner must be the peak rather than the die average. Trivially true as written, and it is here because the hot spot sits inside the multiplier array, which is also where the critical path is -- the hottest transistors are the slowest ones and they are the ones that matter
C-074-6 | t_path_at_face > t_cycle_face | the core's path does not fit a face cycle, which answers 070's question: the two domains cannot be merged, and the crossing in 072 stays
```

## What is still open

**The logic delay is a `given` and everything here rests on it.** Four hundred and
seventy picoseconds through a multiply-accumulate cell is plausible at this node
and `045` has not laid one out.

**The frequency curve is published and the trade is not decided.** `f_face_boost`
says what the faces could run at if the whole thermal margin went to clock.
`027`'s chiller removal wants the same margin. **Both blueprints publish their
claim on it and neither knows about the other's**, which is the clearest
unresolved conflict in the project.

**Nothing budgets the spout's timing here**, though the table names it. `065`
carries its own budget and the two have never been added up.
