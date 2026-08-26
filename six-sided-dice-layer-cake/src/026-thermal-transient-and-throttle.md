# 026 — What happens in the first microsecond

```meta
phase  | 3
issues | 307
```

Steady state is the easy case and it is not the dangerous one. This is the
temperature history at four timescales, and the protection that acts when it goes
wrong.

## The finding, first, because it settles a decision made two phases ago

**The walking hot spot is thermally invisible, and the antipodal face ordering in
`010` earns nothing.**

During single-stream generation exactly one face computes at a time, changing
every hundred and fifty microseconds, so a hot region walks around the cube once
per token. `010` ordered the faces so consecutive stages are antipodal,
reasoning that heat would then land alternately at opposite ends rather than
crawling around one equator.

The silicon does not notice. The thermal time constant of a die's multiplier
region against its own cold plate is about **three milliseconds** — twenty times
longer than a stage. In a hundred and fifty microseconds the array reaches five
per cent of its steady rise, about six tenths of a kelvin, and then the work moves
on. The temperature a face sees is very nearly the average of what it does over
many tokens, and the average is the same under any ordering.

So `010`'s open question closes in the negative. The ordering is free to be used
for something else — the most likely candidate being shorter storage line routing,
which nobody has looked at.

## The four timescales

**Nanoseconds — the load step.** A multiplier array goes idle to full in one
cycle. The thermal mass that responds this fast is the top few microns of
silicon, which is tiny, so a local spike is real in principle. In practice the
step is nanoseconds against a three millisecond constant and the excursion is
microkelvin. **This timescale is an electrical problem, not a thermal one**, and
it is what `031`'s thirty-four microfarads exists for.

**Microseconds — the spout burst.** A hundred and sixty-eight watts appears on
one face for thirty-three microseconds and vanishes: five and a half millijoules
into a face's thermal mass. That is under a millikelvin. The spout's energy
budget in `062` is real as an *energy* accounting question and is thermally
nothing, and this blueprint is where that is confirmed rather than assumed.

**Hundreds of microseconds — the walking hot spot.** Above.

**Seconds — the loop.** Coolant takes several seconds to go round the external
circuit, so a sustained load change takes seconds to reach the radiator and come
back as a changed inlet temperature. **This is a control loop with seconds of
transport delay in front of a millisecond plant**, and one of those must be slow
or it will oscillate. `027` makes it slow.

## The protection

Three levels, each with a threshold, a response and a time.

**Throttle.** Clock and engine utilisation come down. Recoverable, invisible
except as slower generation.

**Halt.** Faces stop issuing. The model stays resident. Recoverable in
microseconds once the temperature falls.

**Cut.** Power removed. Not recoverable without a host. Reserved for coolant
failure, where nothing electrical helps.

The thresholds are ordered and the ordering is a constraint, because four numbers
that are obviously in the right order are exactly the four numbers somebody
retunes one of.

## Where the sensors are matters more than how many

A sensor at the edge of a die reports a temperature the hot region passed through
some time ago. `049` owns placement; this blueprint owns the requirement it must
meet — **sensor lag shorter than the interval between the throttle threshold and
the fatal one, at the worst ramp** — and with a three millisecond plant that is
comfortable, which is worth saying because it is the one place in this phase
where the slow thermal response helps rather than hurts.

## Symbols

```symbols
dT_throttle   | K | given | 15.0  | how far below the silicon's limit the throttle acts
dT_halt       | K | given | 5.0   | how far below it the machine stops issuing
t_sensor      | s | measured | 2e-4 | response time of an on-die temperature sensor, its own settling included
t_throttle    | s | given | 1e-5  | time from the throttle threshold being crossed to engine activity falling

C_engine      | J/K | derived | f_engine_area * A_die * t_die * rho_si * cp_si | thermal mass of the silicon directly under one die's multiplier array
C_face        | J/K | derived | (A_plate * t_coldplate * f_solid_plate * rho_si + 4 * A_die * t_die * rho_si) * cp_si | thermal mass of one face assembly, cold plate and dies
C_core        | J/K | derived | n_tier * A_core_side * (t_lamina * rho_cumo * cp_cumo + t_tier_si * rho_si * cp_si) | thermal mass of the core stack
R_engine      | K/W | derived | dT_conv_local / (f_engine_power * P_die) | thermal resistance from the array to the fluid, from 025's local term
tau_engine    | s   | derived | R_engine * C_engine          | how long the array takes to reach its steady temperature. The number that decides whether any of the fast transients matter
tau_loop      | s   | derived | V_loop / Q_total             | transport delay round the external circuit

t_stage       | s | derived | t_token / n_stage              | how long one face works before the sieve moves on
dT_walk       | K | derived | dT_hotspot * t_stage / tau_engine | temperature excursion of the walking hot spot over one stage, which is the whole of 010's argument reduced to a number
E_spout_burst | J | derived | E_pane * n_pane_core           | energy to push the entire core through the output tube
dT_spout      | K | derived | E_spout_burst / C_face         | what that burst does to the temperature of the face it leaves through
t_to_halt     | s | derived | C_face * (T_si_max - dT_halt - T_j_peak) * n_face / P_heat | how long the machine has, from the design operating point, if all cooling stops at once

T_throttle    | K | derived | T_si_max - dT_throttle         | threshold at which the clock comes down
T_halt        | K | derived | T_si_max - dT_halt             | threshold at which the faces stop
t_lag_budget  | s | derived | (T_halt - T_throttle) * C_face * n_face / P_heat | how long the machine takes to cross from one threshold to the other at full power with no cooling, which is what the sensors must be faster than
```

## Constraints

```constraints
C-026-1 | dT_walk < 1.0                     | the walking hot spot's excursion over one stage must be under a kelvin, which it is by a wide margin. This is 010's ordering argument, checked, and it does not survive: the excursion is small under any ordering and the choice earns nothing
C-026-2 | dT_spout < 0.1                    | pushing the whole core through the output tube must not warm the face it leaves through by a tenth of a kelvin. It does not come close, which is what makes the spout an energy budget rather than a power one
C-026-3 | T_j_peak < T_throttle             | the design operating point must sit below the throttle threshold, or the machine throttles constantly
C-026-4 | T_throttle < T_halt               | throttle below halt
C-026-5 | T_halt < T_si_max                 | and halt below the fatal temperature. Three constraints on four numbers that are obviously in the right order, which is exactly the situation where one of them gets retuned and the order quietly breaks
C-026-6 | t_sensor + t_throttle < t_lag_budget | the sensors must see and the throttle must act before the machine crosses from one threshold to the next at full power with no cooling
C-026-7 | tau_engine > t_stage * 10         | the thermal response must be slow compared with a pipeline stage, which is what makes the walking hot spot a non-event and the sensor timing comfortable
C-026-8 | t_to_halt > t_interlock           | the machine must survive total cooling loss for longer than 027's interlock takes to cut power
```

## What is still open

**The load step's electrical consequence is real even though its thermal one is
not.** Nothing in this blueprint says so beyond a sentence, and `031` is where it
lives — but somebody reading only this file would come away thinking a load step
is harmless, which it is not.

**`t_to_halt` assumes the coolant stops being present rather than stops moving.**
Stagnant fluid still conducts and still has heat capacity, so the real time is
longer and the calculation here is conservative. Whether it is conservative by
twenty per cent or by a factor of three has not been worked out, and `027` sizes
its interlock against it.

**One channel blocking is not modelled at any timescale.** `009` entry T2.
