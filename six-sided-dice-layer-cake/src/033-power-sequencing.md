# 033 — Turning it on, and losing it

```meta
phase  | 4
issues | 406
```

## Why order matters at all

**Latch-up.** A signal driven into an input whose supply is not yet valid
forward-biases a parasitic junction and creates a low-resistance path that
persists until power is removed. It destroys parts. The rule that prevents it —
a domain's inputs may not be driven before its own supply is up — orders the
whole tree.

**Inrush.** Every capacitor `031` placed has to be charged. Three microfarads a
die times twenty-four, plus the core's, is over a hundred microfarads at three
quarters of a volt. Bringing that up in a microsecond wants kiloamperes, so the
ramp rate is limited and the limit sets the power-up time.

## The order

```drawing
up, and down [not-dimensioned]

   up      [V_aux] ──▶ [V_port] ──▶ [V_array] ──▶ [V_logic] ──▶ [V_link]
              │                        │
              │                        └── memory stable before anything reads it
              └── the interlock must be watching before anything else exists

   down    [V_link] ──▶ [V_logic] ──▶ [V_array] ──▶ [V_port] ──▶ [V_aux]
                                         │                          │
                                         │                          └── last, and
                                         └── held up on stored          on stored
                                             charge long enough          charge long
                                             for writes to finish        enough to
                                                                         say why
```

Link last on the way up because it has the smallest swing and the least noise
margin. Array before logic so that memory is stable before anything reads it.
Auxiliary first and last, because the interlock in `027` cannot be powered by the
thing it is cutting.

## The uncommanded case, which is the real content

**Brownout.** The forty-eight volt input sags mid-token. Three things could
happen and the design must choose the second.

*The core loses its contents.* Sixty-four gibibytes of resident model gone,
thirty milliseconds to reload from the storage lines. Survivable and detectable.

*The core keeps its contents.* Static memory holds as long as its rail does, so
if the array domain is held up on stored energy while the logic collapses, the
model survives and only the in-flight token is lost. **This costs a bulk
capacitor and is worth it** — thirty milliseconds of reload against a few
millijoules of storage, and a machine that does not lose its model on a flicker
is a different machine to operate.

*The core keeps half its contents.* Unacceptable, and it is what would happen
today, because nothing distinguishes a completed write from an interrupted one.
The mechanism that makes it impossible is that **the array rail's collapse must
be slower than the longest write in flight**, so writes finish rather than tear.

## Symbols

```symbols
brownout_frac | 1 | given | 0.90  | fraction of nominal at which the supply is declared to have failed
t_detect      | s | given | 2.0e-5 | from the supply crossing that threshold to the machine being told
t_ramp_dom    | s | given | 1.0e-3 | how long one domain takes to come up, set by the inrush limit
n_up_step     | 1 | derived | n_domain | steps in the power-up sequence, one per domain
C_decouple_all| F | derived | n_die * C_ramped + C_core_decouple | every decoupling capacitor in the machine
C_core_decouple | F | given | 5.0e-5 | decoupling on the array rail inside the core and the cage
I_inrush      | A | derived | C_decouple_all * V_logic / t_ramp_dom | current drawn charging all of it over one domain's ramp
t_powerup     | s | derived | n_up_step * t_ramp_dom + t_lock       | from supplies valid to reset released
t_lock        | s | given | 5.0e-4 | time for the reference and the multipliers in 070 to settle
E_holdup      | J | derived | C_array_holdup * V_array^2 / 2        | energy stored to keep the array rail alive while the logic collapses
C_array_holdup| F | given | 3.0e-4 | bulk capacitance on the array rail whose only job is to keep the model alive through a supply sag. A real component chosen for its value, not a quantity derived from what it must achieve -- the point of the constraint below is to check a choice, and a value derived from the requirement would check nothing
t_holdup      | s | derived | C_array_holdup * V_array * tol_rail / I_array | how long that actually lasts
E_aux_holdup  | J | given | 5.0e-3 | energy reserved to keep the auxiliary domain alive long enough to write a fault record
t_down_emerg  | s | given | 1.0e-4 | emergency down-sequence, ordered but fast, used when 027's interlock cuts on coolant loss
t_holdup_ref  | s | given | 1.0e-3 | a millisecond, as the reference the hold-up energy is judged small against
t_powerup_max | s | given | 0.100  | the longest the supplies may take to reach the point where reset can be released; a person waiting for a machine notices a tenth of a second and not much less
```

## Constraints

```constraints
C-033-1 | t_holdup > t_write_max        | the array rail must stay inside tolerance for longer than the longest write in flight. This is the constraint that makes the third brownout outcome impossible: without it a supply sag leaves the model half written, with nothing anywhere able to tell
C-033-2 | I_inrush < I_supply * 3       | charging every capacitor in the machine must not draw more than a few times the running current, or the supply trips on its own start
C-033-3 | t_down_emerg < t_to_halt      | the emergency sequence must finish before the machine reaches its thermal halt threshold with cooling stopped
C-033-4 | E_holdup < P_heat * t_holdup_ref | the energy held to keep the model alive must be small against what the machine spends in a millisecond, which is what makes this a cheap addition rather than a design constraint
C-033-5 | n_up_step == n_domain         | one step per domain, so a domain added without a sequencing step is caught
C-033-6 | t_powerup < t_powerup_max      | the machine must reach the point where reset can be released quickly enough that 073's ten-step boot is the long part rather than this. Written first as a comparison against a bare tenth, which the checker refused -- a literal in this notation is always dimensionless, so a time is only ever compared against a named time
C-033-7 | brownout_frac < 1 - tol_rail  | the brownout threshold must sit below the bottom of the normal tolerance band, or the machine declares a failure every time the supply is merely low
```

## What is still open

**The fault record has nowhere to go.** `E_aux_holdup` reserves energy to write
one and nothing in this machine is non-volatile — the same gap `009` entry M4
records for the repair map. A fault record written into static memory that is
about to lose its rail is not a record.

**Nothing says what the regulators do on a sagging input.** `030` notices the
regulator is unspecified and this blueprint needs its behaviour below the
brownout threshold: whether it holds the output and draws more current, or folds
back. The two produce opposite outcomes for the hold-up scheme above.

**The down-sequence assumes the machine is listening.** An emergency cut arrives
from `027`'s interlock, which is deliberately independent of anything running on
the cube. If the cube is hung, nothing executes an ordered shutdown and the cut
is abrupt — which is correct, and means the ordered sequence is a nicety for the
commanded case rather than a protection for the uncommanded one.
