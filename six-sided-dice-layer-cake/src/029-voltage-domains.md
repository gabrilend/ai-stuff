# 029 — Five voltages, or four

```meta
phase  | 4
issues | 402
```

A domain is expensive — its own regulator, its own plane, its own decoupling, its
own step in the power-up sequence — so each one has to earn itself.

| domain | volts | feeds | why it is not merged with its neighbour |
|---|---|---|---|
| `V_logic` | 0.75 | engines, control, the crossbar | the largest load; everything is measured against it |
| `V_array` | 0.85 | face slices and the core tiers | cells need more headroom than logic to stay stable while being read |
| `V_link` | 0.60 | radial link drivers | a short reach permits a small swing, and energy goes as its square |
| `V_port` | 1.20 | port fields, storage lines, the spout | must interoperate with things this machine did not design |
| `V_aux` | 3.30 | sensors, telemetry, the interlock | must survive when everything else is off |

## The three arguments worth making properly

**Array against logic.** Running the whole die at the array's voltage costs about
a tenth of the total power for nothing. Running the array at the logic voltage
costs read stability, which shows up as a soft error rate rather than as a
failure — which is worse, because a machine that fails loudly can be fixed. The
tenth is derived below rather than asserted.

**The link's small swing.** Energy per bit goes as the square of the swing and the
link carries everything the core delivers. Six hundred millivolts against seven
hundred and fifty saves over a third of a term worth tens of watts. The limit is
noise margin across the radial interface, which is `051`'s to state, and this
blueprint reads it rather than assuming it.

**Auxiliary must outlive the others.** The interlock in `027` cuts power when the
coolant stops, so it cannot be powered by the thing it is cutting. This is the
only domain justified by a failure rather than by efficiency, and it is the one
most likely to be dropped by somebody optimising.

## Symbols

```symbols
V_supply     | V | given | 48.0  | what arrives from outside. Chosen because it is the highest voltage that is still ordinary to distribute and connect without special handling
V_mid        | V | given | 5.0   | the intermediate rail on a face interposer, between the two conversion stages
V_logic      | V | given | 0.75  | logic and multiplier arrays
V_array      | V | given | 0.85  | static memory cells, in the slices and in the core
V_link       | V | given | 0.60  | radial link drivers, low swing by design
V_port       | V | given | 1.20  | port field transceivers
V_aux        | V | given | 3.30  | sensors, telemetry and the interlock
tol_rail     | 1 | given | 0.05  | fractional tolerance band on every rail, worst case over the operating range
droop_frac   | 1 | given | 0.03  | fraction of nominal a rail may droop transiently under a load step
ripple_frac  | 1 | given | 0.01  | fraction of nominal a rail may carry as switching ripple
dV_read_marg | V | given | 0.08  | the least the array rail must exceed the logic rail by for a static memory cell to stay stable while it is read, at the worst process corner and the highest temperature
n_domain     | 1 | given | 5     | supply domains

dV_droop_logic | V | derived | V_logic * droop_frac         | how far the logic rail may fall during a load step, which is what sizes the decoupling in 031
dV_ripple      | V | derived | V_logic * ripple_frac        | switching ripple allowed on the same
dV_band        | V | derived | V_logic * tol_rail           | the whole tolerance band the rail must stay inside
P_if_merged    | W | derived | P_logic_load * (V_array / V_logic - 1) | what running the logic at the array's voltage would cost, which is the argument for keeping them apart
f_merge_cost   | 1 | derived | P_if_merged / P_load         | that cost as a share of the machine
E_swing_ratio  | 1 | derived | (V_link / V_logic)^2         | the energy the link saves by swinging six hundred millivolts instead of the logic rail's, since energy goes as the square of the swing
P_link_if_logic| W | derived | P_link_load / E_swing_ratio  | what the link would cost at the logic swing
```

## Constraints

```constraints
C-029-1 | dV_droop_logic + dV_ripple < dV_band | droop plus ripple must fit inside the tolerance band. Otherwise the rail is out of specification during normal operation, which is the kind of thing that is obviously wrong and quietly true
C-029-2 | V_array >= V_logic + dV_read_marg    | the array rail must exceed the logic rail by the read stability margin, which is the entire reason there are two
C-029-3 | V_link >= V_link_min                 | the link swing must exceed the noise margin 051 needs across the radial interface. This blueprint reads that number rather than assuming it, and 051 reads this one, so neither may quietly move
C-029-4 | f_merge_cost > 0.05                  | merging the array rail into the logic rail must cost more than a twentieth of the machine's power, or the second domain is not earning its regulator. Asserted in the direction that keeps the domain
C-029-5 | P_link_if_logic > P_link_load        | the low swing must actually save something
C-029-6 | V_mid < V_supply                     | the intermediate rail sits between the supply and the load, which is trivially true and catches the two being edited in the wrong direction
C-029-7 | n_domain == 5                        | five domains. Asserted so that adding a sixth is a deliberate act with an argument attached rather than something that happens
```

## What is still open

**`009` entry P1 belongs to `030`, not here**, but it is decided by the same
people: five volts or twelve as the intermediate. Twelve quarters the current in
the interposer planes and makes the second conversion ratio sixteen to one
instead of six and a half. It changes plane thickness, which changes face
thickness, which changes the cube.

**The merge analysis only covers one merge.** Port into auxiliary, and link into
logic, are both plausible and neither is priced. The first would save a regulator
and cost the ability to power the interlock separately, which is not a trade
anybody should make casually and nobody has written down.
