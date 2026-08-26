# 032 — How thin a wire is allowed to be

```meta
phase  | 4
issues | 405
```

## The mechanism, because the number is meaningless without it

Electrons crossing a metal conductor collide with its atoms and push them
downstream. At low current density the metal's own diffusion repairs the damage.
Above a threshold it does not, and material piles up at one end of a conductor
and is stripped from the other until a void opens the line or a hillock shorts it
to its neighbour.

The rate depends on current density and, far more strongly, on temperature — it
goes as an exponential in the reciprocal of absolute temperature. **So a
conductor qualified at eighty-five degrees is not qualified at a hundred and
five**, and quoting a limit without a temperature is the mistake this blueprint
exists to prevent. `011` carries the figure at the operating temperature from
`025`, and `C-032-5` checks that the two agree.

## The two failure modes are not the same

An **open** is benign in the sense that the machine stops and somebody notices. A
**hillock short** between a power conductor and a signal conductor is not: the
machine keeps running and produces wrong answers. Spacing rules matter as much as
width rules and are more often forgotten, so both are here.

## Where it binds, which is not where it was expected to

The ticket predicted the via islands. It is not them: at the supply voltage they
carry a few amperes through several hundred pads each, which is three orders of
magnitude of headroom.

**It is the die's own power grid.** Seventy amperes into a twenty-four millimetre
die needs about seventy thousand square microns of cross-section, and the top
metal layer at three microns thick gives seventy-two thousand across the die's
full width if six tenths of it goes to power. That is the binding case and it is
close.

## Symbols

```symbols
sp_hillock    | um | given | 0.40 | least spacing between a power conductor and a signal conductor at the top metal level, so that a hillock cannot bridge them
n_yr_life     | 1  | given | 10.0 | years the conductors must survive at the design current, from 086
T_em_quoted   | K  | given | 319.0 | temperature the current density limit in 011 is quoted at. It was three hundred and fifty, which is where the conductors were assumed to run before 025's chain closed; they run cooler, and a limit quoted hot is conservative rather than wrong -- but a limit quoted at the wrong temperature at all is how this goes wrong silently

A_req_die     | um^2 | derived | I_die_logic / j_em_cu                    | cross-section one die's logic current needs
A_grid_avail  | um^2 | derived | L_die * t_grid_metal * f_grid_metal | cross-section the top metal actually provides across the die's width
m_grid        | 1    | derived | A_grid_avail / A_req_die                 | margin at the binding case
A_req_island  | um^2 | derived | I_face_supply / j_em_cu                  | cross-section the via islands need
A_isl_avail   | um^2 | derived | n_island_pad * pi * (p_island_pad * 250)^2 | cross-section they provide, taking a pad as a quarter of its pitch in radius
m_island      | 1    | derived | A_isl_avail / A_req_island               | margin there, which is the number that showed the islands are not the problem
A_req_pillar  | um^2 | derived | I_core_face / j_em_cu                    | cross-section the inward core supply needs at one radial interface
A_pil_avail   | um^2 | derived | n_pillar_pwr * pi * (d_radial_pad * 500)^2 | cross-section the power pillars provide
m_pillar      | 1    | derived | A_pil_avail / A_req_pillar               | margin there
m_worst       | 1    | derived | min(min(m_grid, m_island), m_pillar)     | the binding case across all three
j_grid        | mA/um^2 | derived | I_die_logic / A_grid_avail            | actual current density in the die power grid, which is the number a process engineer will ask for
```

## Constraints

```constraints
C-032-1 | m_worst > 1.5                | every conductor must carry its current with half again to spare at the operating temperature over the ten year life. Not a large margin, and the binding case is the die's own power grid rather than the via islands the ticket expected
C-032-2 | j_grid < j_em_cu             | the die power grid's actual current density must be under the limit; the same statement where it binds
C-032-3 | m_island > 100               | the via islands must have orders of magnitude of headroom, because they are already a sealing problem and adding an electrical one to the same feature would be a bad place for two risks to meet
C-032-4 | sp_hillock > 0               | a spacing rule must exist. Trivial, and it is here because the hillock short is the failure that keeps the machine running while it produces wrong answers, and a rule that is merely intended is not one
C-032-5 | T_em_quoted ~= T_j_peak      | the temperature the current density limit is quoted at must be the temperature the conductors actually run at, from 025's chain. This is the cross-blueprint check the whole blueprint exists to make, because the ordinary way to get electromigration wrong is to use a datasheet number from a cooler part
C-032-6 | n_yr_life >= 10.0            | the life this is sized for must match what 086 claims
```

## What is still open

**The margin at the binding case is one and a half, and that is thin.** It rests
on a top metal thickness and a power-versus-signal split that `041` has not
finalised, on a current density limit quoted with no source, and on a junction
temperature that itself rests on a floorplan and an unsolved flow network. Three
uncertainties multiply into this one number and none of them is small.

**Nothing considers the peak.** Every current here is the design point average.
`031` establishes that a die's current goes from nothing to sixty amperes in
forty-five nanoseconds, and electromigration depends on the time average rather
than the peak, so this is defensible — but nobody has written down that it is
defensible, which is different from it being so.

**The interposer planes are not in the list.** Three conductors are checked and
the planes carrying the intermediate rail across a face are not, on the grounds
that the current there is small. At five volts it is, and `009` entry P1 asks
whether the intermediate should be twelve — which would make it smaller still, or
five, which is the case actually built.
