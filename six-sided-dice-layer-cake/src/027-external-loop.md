# 027 — Everything outside the cube

```meta
phase  | 3
issues | 308
```

The cube is a heat exchanger with a specified inlet condition. Something has to
produce that condition, and if it cannot, every number in phase 3 is wrong.

## The trade this blueprint exists to make explicit

`025` reports something like forty kelvin of margin between the hottest transistor
and what the silicon tolerates. That margin has to be **spent somewhere**, and the
best place is here.

A twenty-five degree coolant inlet in a twenty-two degree room means a three
kelvin approach across the radiator, which for nineteen hundred watts needs a
conductance no air-cooled radiator of a sensible size delivers. **It needs a
refrigeration plant** — a compressor, a condenser, a second loop, and several
hundred watts of its own.

A fifty degree inlet needs a twenty-eight kelvin approach, which a radiator and a
fan manage easily. The junction goes to about ninety degrees, which is still
inside the qualification with room to spare.

**Removing a chiller from the bill of materials is worth more than fifteen kelvin
of junction temperature**, and this blueprint should be read as the argument for
raising the inlet rather than as a description of a cooling plant.

## The pieces

```drawing
the circuit outside the cube [not-dimensioned]

   ┌──── cube ────┐
   │  4 inlets    │◀───────────┬──── pump ────┬──── filter ────┐
   │  4 outlets   │───────────▶│              │                │
   └──────────────┘            │         redundant pump        │
          │                    │                               │
          └──── radiator ──────┴──── reservoir ────────────────┘
                    │
                   fan                     interlock watches flow,
                                           and cuts power, not the pump
```

**The pump** has a trivial duty — a few litres a minute against a fifth of a bar
— and two requirements that are not trivial. It must not shed particles into a
hundred and fifty micron channel, and it must be redundant, because `026` says
the machine has about a second from the design point if all cooling stops.

Redundancy is cheap here because of the property in `024`: in laminar flow the
convection coefficient does not depend on velocity, so **losing one of two pumps
costs about four kelvin, not half the cooling.** A machine running on one pump is
a machine that keeps working and says so.

**The radiator** is where the margin is spent, above.

**Filtration** is the single specification protecting the microchannels, and its
absolute rating has to be a stated fraction of the channel width rather than a
number somebody liked. A filter also raises system resistance as it loads, which
moves the duty point in `024` — so the machine must notice a loading filter
before a channel does.

**The interlock** is the one fault where nothing electrical helps. It must be
independent of anything running on the cube, because a cube that is overheating
is a cube that cannot be trusted to notice, and it must cut **power** rather than
try to fix the flow.

## Symbols

```symbols
T_in_max      | K     | given | 333.0 | the warmest coolant the seals, the elastomer and the materials in 011 tolerate at the working pressure
dT_margin_dry | K     | given | 15.0  | the least junction margin that must remain once the chiller is removed and the inlet floats to whatever an air-cooled radiator gives
UA_rad        | W/K   | given | 60.0  | conductance of an air-cooled radiator of a size that fits beside this machine, with its fan running
d_filter      | um    | given | 25.0  | absolute rating of the filter; the largest particle it passes
dp_filter_new | Pa    | given | 3000  | pressure across a clean filter element
dp_filter_end | Pa    | given | 15000 | pressure across one loaded enough to be changed
V_loop_ext    | mm^3  | given | 2.0e5 | fluid in the pump, radiator, reservoir and tubing, outside the cube
V_reservoir   | mm^3  | given | 5.0e4 | reservoir capacity
t_interlock   | s     | given | 0.100 | from flow loss detected to power removed
t_service_int | s     | given | 3.15e7 | interval between services, one year
n_pump        | 1     | given | 2     | pumps, one running and one held
beta_water    | 1/K   | measured | 4.0e-4 | volumetric thermal expansion of water near the operating temperature

V_loop        | mm^3 | derived | V_coolant + V_loop_ext        | fluid in the whole circuit
dT_rad        | K    | derived | P_heat / UA_rad               | temperature the coolant must sit above the room for the radiator to reject the heat
T_in_no_chill | K    | derived | T_room + dT_rad               | the coldest inlet an air-cooled radiator alone can produce
dT_chiller    | K    | derived | T_in_no_chill - T_coolant_in  | how much colder the requested inlet is than an air-cooled radiator alone can produce. Positive means a refrigeration plant, and how far positive is how much of one. Written as a temperature rather than as a boolean because this notation has no conditionals and a quantity says more than a flag would
T_j_no_chill  | K    | derived | T_j_peak - T_coolant_in + T_in_no_chill | junction temperature if the chiller is removed and the inlet allowed to float to what the radiator gives
margin_no_chill | K  | derived | T_si_max - T_j_no_chill       | and how much margin is left after doing that

V_expansion   | mm^3 | derived | V_loop * beta_water * dT_rise * 4 | fluid volume change over the operating range, taken over four times the design rise to cover a cold start
Q_leak_max    | m^3/s | derived | V_makeup / t_service_int      | volumetric loss the reservoir can absorb over one service interval once thermal expansion and service spillage are allowed for
V_makeup      | mm^3 | derived | V_reservoir - V_expansion - V_spill_life | reservoir capacity left over for leakage, once expansion and the spillage 019 loses at every coupling are taken out
dp_ext        | Pa   | derived | dp_filter_end + dp_rad + dp_tube | pressure the external circuit costs when the filter is at the end of its life
dp_rad        | Pa   | given | 8000  | pressure across the radiator core at design flow
dp_tube       | Pa   | given | 4000  | pressure across the tubing and fittings
dp_system     | Pa   | derived | dp_loop + dp_ext             | the whole circuit, inside and out, at end-of-life filter loading
P_pump_total  | W    | derived | dp_system * Q_total / eta_pump | electrical power the pump draws against the whole system
t_to_halt_1pump | K  | derived | dT_rise                       | the extra coolant rise on one pump: flow halves, so the fluid's own rise doubles, and nothing else in the chain changes
```

## Constraints

```constraints
C-027-1 | T_in_no_chill < T_in_max                    | the inlet an air-cooled radiator alone produces must be one the machine's own materials tolerate. Written first as the radiator rejecting the heat, which is how T_in_no_chill is defined and therefore says nothing at all
C-027-2 | margin_no_chill > dT_margin_dry | with the chiller removed and the inlet floating to whatever the radiator gives, there must still be fifteen kelvin between the hottest transistor and its limit. This is the constraint that says the trade is available, and it is the most useful line in the blueprint
C-027-3 | t_interlock < t_to_halt    | the interlock must cut power before the machine reaches its halt threshold with all cooling stopped
C-027-4 | d_filter * 3 < w_uchan        | the filter must pass nothing bigger than a third of a channel's width, so that no single particle can close one. Written first with a thousand in it -- microns against millimetres, converted by hand in a notation that converts -- which made the check pass by a factor of a thousand while appearing to hold
C-027-5 | V_makeup > V_leak_life        | what the reservoir has left, after thermal expansion and service spillage, must still cover a service interval's worth of leakage from a hundred and sixty-six joints
C-027-6 | dp_system < p_work         | the whole circuit, with the filter at the end of its life, must stay inside the working pressure the seals are rated for
C-027-7 | n_pump >= 2                | one pump is a single point of failure on a machine with about a second of thermal inertia. Two is the minimum and the cost is small because losing one costs four kelvin rather than half the cooling
```

## Symbols this needs and owns

```symbols
V_leak_life   | mm^3 | derived | Q_leak_total * t_service_int | fluid actually lost to leakage over one service interval, at the rate 017's hundred and sixty-six joints add up to
```

## What is still open

**The inlet temperature is still specified at twenty-five degrees** in `021`, and
this blueprint's whole argument is that it should not be. Changing it is one
edit and a rerun; it has not been made because the junction temperatures printed
throughout the documentation assume the cold inlet, and reconciling those is a
pass somebody has to do deliberately rather than by accident.

**Fouling is not modelled.** The filter rating protects against particles. Nothing
protects against scale, corrosion products or biological growth, all of which
have length scales comparable to a hundred and fifty micron channel and all of
which accumulate over the years `086` is claiming.

**The interlock's own reliability is not specified.** It is the last line of
defence against the one failure that destroys the machine, and nothing says how
often it fails to fire, or what tests that.
