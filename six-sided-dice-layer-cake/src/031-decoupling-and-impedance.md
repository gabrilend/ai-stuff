# 031 — Holding the rail up for ten nanoseconds

```meta
phase  | 4
issues | 404
```

## The problem

A multiplier array is sixty-five thousand cells that either have operands or do
not. It goes from idle to fully switching **in one clock cycle**: sixty amperes
in about a nanosecond.

A regulator, however good, takes tens of nanoseconds to notice. In between,
nothing holds the rail up except stored charge.

    C  =  I_step * t_response / dV_droop

Sixty amperes, ten nanoseconds, twenty-two millivolts: **twenty-seven microfarads
per die.** At the hundred nanofarads per square millimetre a deep trench array
gives, that is two hundred and seventy square millimetres of interposer under a
five hundred and seventy-six square millimetre die.

**Decoupling is a floorplan constraint**, not a component to add at the end, and
this blueprint presents it that way.

## The other half of the answer: do not make the step

`048`'s sequencer admits operands progressively over sixty-four cycles rather
than all at once. That does not change the total current — it changes how fast it
arrives, and the charge the capacitors have to supply is the *deficit* while the
regulator catches up, which falls as the square of the ratio.

Sixty-four cycles at the face clock is about forty-five nanoseconds against a ten
nanosecond regulator, and the required capacitance falls from twenty-seven
microfarads to about three. **Forty-five nanoseconds at the start of a layer that
takes a hundred and fifty microseconds — three parts in ten thousand of the time
— for a factor of nine on the hardest electrical problem in the machine.**

## The impedance target

Droop divided by step current gives a target impedance the network must stay
under from direct current up to the clock. Three regions hold it: the regulator
at low frequency, the trench array in the middle, on-die capacitance at the top.

**The dangerous part is where two regions meet.** An inductance and a capacitance
in series resonate there, and an antiresonant peak above the target is a rail
that rings at exactly the frequency the engine switches at.

```drawing
the impedance the network must stay under [not-dimensioned]

   |Z|
    │        regulator      trench array      on-die
    │       ◄─────────►   ◄────────────►   ◄────────►
    │  ╲                ╱╲              ╱╲
    │   ╲______________╱  ╲____________╱  ╲______
    │ ─────────────────────────────────────────────  [Z_target]
    │            ▲                  ▲
    │            └── antiresonance ─┘   the two places it can rise
    └──────────────────────────────────────────────▶  frequency
```

## Symbols

```symbols
t_reg_resp    | s      | given | 1.0e-8 | how long an integrated regulator takes to respond to a load step
c_trench      | nF/mm^2| measured | 100.0 | capacitance per unit area of a deep trench capacitor array in the interposer
n_ramp_cycle  | 1      | given | 64     | cycles over which 048 admits operands at the start of an operation
f_antires     | 1      | given | 3.0    | how far above the target impedance an unmitigated antiresonant peak sits, as a multiple

I_step_die    | A  | derived | P_engine_die / V_logic                      | current one die's multiplier array demands when it goes from idle to full
t_ramp        | s  | derived | n_ramp_cycle / f_face                       | how long the sequencer takes to get there
slew_raw      | A/s| derived | I_step_die / (1 / f_face)                   | current slew if the array started all at once, in one cycle
slew_ramped   | A/s| derived | I_step_die / t_ramp                         | and with the ramp
C_raw         | F  | derived | I_step_die * t_reg_resp / dV_droop_logic    | decoupling one die would need with no ramp: the whole step, held for the regulator's whole response
C_ramped      | F  | derived | I_step_die * t_reg_resp^2 / (2 * t_ramp * dV_droop_logic) | and with it: the deficit while the regulator catches a ramp is the area of a triangle rather than a rectangle
ramp_gain     | 1  | derived | C_raw / C_ramped                            | what the sixty-four cycles buy
A_trench_die  | mm^2 | derived | C_ramped / c_trench                       | interposer area one die's decoupling occupies
A_trench_all  | mm^2 | derived | n_die * A_trench_die                      | and all of it
f_trench_area | 1  | derived | A_trench_die / A_die                        | that area as a share of the die it sits under
Z_target      | ohm| derived | dV_droop_logic / I_step_die                 | impedance the network must stay under across frequency
Z_peak        | ohm| derived | Z_target * f_antires                        | where an unmitigated antiresonance would put it
f_ramp_cost   | 1  | derived | t_ramp / t_layer                            | what the ramp costs as a share of the time a layer takes
E_stored      | J  | derived | n_die * C_ramped * V_logic^2 / 2            | energy held in the decoupling across the machine, which 033 has to discharge safely
```

## Constraints

```constraints
C-031-1 | A_trench_die <= A_die            | the decoupling for one die must fit in the interposer area beneath it. With no ramp it does not, which is the whole reason the ramp exists
C-031-2 | f_trench_area < 0.20             | and should take under a fifth of it, because the interposer also has to carry planes and routing
C-031-3 | f_ramp_cost < 0.001              | the ramp must cost under a thousandth of a layer's time. Three parts in ten thousand for a factor of nine on the capacitance is the best trade in the phase, and asserting it means a longer ramp has to argue for itself
C-031-4 | ramp_gain > 5.0                  | the ramp must be worth having
C-031-5 | Z_peak < dV_band / I_step_die    | even at an antiresonant peak the network must keep the rail inside its tolerance band. This is the constraint that fails when somebody removes a capacitor bank without checking what it was damping
C-031-6 | slew_ramped < slew_raw           | the ramp reduces the slew, which is trivially true and catches a ramp length edited to zero
```

## What is still open

**The regulator's response time is a `given` with nothing behind it.** Ten
nanoseconds is what an integrated switching regulator of this class can do and
the capacitance goes as its square under the ramp, so a regulator twice as slow
needs four times the trench area — which does not fit. `030` also notices that
the regulator is nowhere specified.

**The antiresonant factor is a guess.** Three times the target is the right order
for an undamped two-stage network and the real figure depends on the parasitic
inductance between the trench array and the die, which nobody has extracted.

**Nothing models six dies stepping at once.** Each die is treated alone. At the
crossover batch all twenty-four are switching together, and whether their steps
correlate depends on `053`'s schedule — if they do, the interposer planes and the
via islands see twenty-four times the slew and neither has been checked for it.
