# 019 — Mounting, and taking it away

```meta
phase  | 2
issues | 207
```

How a sealed cube with a live coolant loop through it, six connectors on six
different faces and no serviceable interior is attached to the world, and later
removed from it.

## Why this is not a formality

The shape is hostile to every convention. A card slides out of a slot. A socketed
processor lifts off a board. **A cube cannot be pulled in any direction without
disconnecting five faces first**, and two of those connections carry water.

## The four rules

**One mechanical interface, not six.** Load goes into the four corner blocks of
one chosen face, which `015` already makes the stiffest points on the object.
Every other connector carries signal and must carry no load whatever; a port
field taking mechanical stress is a port field that fails in the field.

**The coolant connects and disconnects dry.** Four inlets and four outlets, each
a self-sealing coupling that closes both halves when parted. The drop each one
loses on parting, times eight, times the number of service events in the
machine's life, is a real volume and it belongs in `027`'s make-up.

**Gravity is not assumed.** Six equivalent faces and no natural up. Whichever
face is mounted, the loop must purge air from all twelve rails, so the highest
point in *any* permitted orientation must have a vent path. Four of the eight
corners are already outlets; the vent goes there, and only orientations where an
outlet is the high point are permitted.

**Three points constrain a rigid body; four bolts over-constrain it.** The fourth
mount must be compliant, with travel sized from `018`'s differential expansion
between a steel frame and a mostly-steel cube.

## What service means

Nothing inside a cube is serviceable. There are no field-replaceable parts, no
way to reach a die, and no way to reopen a bond. **Service means replacing the
whole cube**, and this blueprint exists to make that twenty minutes rather than a
morning.

That should be said plainly, because a specification implying serviceability it
does not have is worse than one that admits the truth. `086` is where the
consequence lands: with no repair path, the reliability target must be met by the
part rather than by maintenance.

## Symbols

```symbols
n_mount       | 1  | given | 4     | mount points, on the four corner blocks of one chosen face
n_mount_rigid | 1  | given | 3     | of those, how many are rigid; the fourth is compliant so the frame does not over-constrain the cube
g_shock       | 1  | given | 50.0  | shock the mounted assembly must survive in transit, in multiples of gravity
g_accel       | m/s^2 | measured | 9.81 | standard gravity
d_bolt        | mm | given | 3.0   | bolt diameter at each mount point; four millimetres needs exactly the whole corner block and leaves nothing around it
V_coupling    | mm^3 | measured | 100.0 | fluid lost when one self-sealing coupling is parted, from the coupling's own data
n_service     | 1  | given | 5     | service events -- cube replacements -- expected over the life of an installation
cte_frame     | ppm/K | derived | cte_ss | the frame is steel, and so is most of the cube's exterior
dT_frame      | K  | given | 40.0  | temperature difference the frame and the cube can be at, worst case
T_touch       | K  | given | 318.0 | the warmest surface a person may put a bare hand on. Forty-five degrees Celsius, which is the ordinary limit for a metal surface somebody has to grip rather than brush past
n_tau_cool    | 1  | given | 3.0   | thermal time constants to wait before the cube is called cool. Three leaves five per cent of the excess, and the fourth would buy one per cent for another third of the wait
t_stop        | s  | given | 60.0  | stopping the machine in an orderly way: finish the token in flight, drain the six pipeline stages, park the model, stop the clock
t_valve       | s  | given | 120.0 | closing the isolation valves either side of the cube and letting the loop pressure fall to nothing, twice -- once out and once in
t_couple      | s  | given | 45.0  | parting or making one self-sealing coolant coupling by hand, including wiping the face
t_bolt        | s  | given | 90.0  | releasing or torquing one mount point, including checking the torque
t_lift        | s  | given | 60.0  | lifting the cube out of the frame and the replacement into it. A sixty-millimetre cube weighing a little over a kilogram wet is a one-hand object, and the time is care rather than effort
t_align       | s  | given | 180.0 | seating the replacement against the three rigid mounts and setting the compliant one, which is where the time goes if it goes anywhere
t_purge       | s  | given | 600.0 | filling and purging the new cube, until no air returns from the outlet corners

m_mounted     | kg | derived | m_cube                                   | mass the frame carries
F_mount_static| N  | derived | m_mounted * g_accel / n_mount            | static load at one mount point
F_mount_shock | N  | derived | m_mounted * g_accel * g_shock / n_mount  | load at one mount point under transit shock
disp_frame    | mm | derived | (cte_frame - cte_ss) * dT_frame * L_cube | differential motion between frame and cube over the worst temperature difference
travel_compliant | mm | derived | 4 * (cte_frame + cte_ss) * dT_frame * L_cube | travel the compliant mount must allow, taken generously because the frame's own material is not settled
V_spill_event | mm^3 | derived | 2 * n_corner_in * V_coupling            | fluid lost in one service event, all eight couplings parted
V_spill_life  | mm^3 | derived | V_spill_event * n_service               | fluid lost over the installation's life
n_orient      | 1  | derived | n_face                                  | mounting orientations to check, one per face that could be the mounted one

C_cube        | J/K | derived | (m_tiers + m_coldplate + m_dies) * cp_si + m_laminae * cp_cumo + (m_rails + m_corners + m_ports) * cp_ss + m_coolant * cp_water + m_cage * cp_si | heat the whole machine holds per kelvin, summed over what it is made of. The cage is taken as silicon because it is a switch shell of dies, and the interposer is left out as glass with a tenth the mass of anything else here
R_cube_cool   | K/W | derived | (T_j_peak - T_coolant_in) / P_heat     | the cube's whole thermal resistance to the coolant, read backwards out of the steady state: the temperature it sits at above the inlet, divided by the heat it was rejecting to get there
tau_cube      | s  | derived | C_cube * R_cube_cool                    | how long the machine takes to fall to a third of its excess temperature with the power off and the pump still running. Not the engine's time constant in 026, which is the array alone and is a thousand times shorter -- this is the whole object
t_cool_hold   | s  | derived | n_tau_cool * tau_cube                   | how long to hold with the pump running before opening anything. The pump outlives the power to the dies for exactly this reason
n_couple      | 1  | derived | 2 * n_corner                            | coolant couplings to part and then make: one supply and one return at every corner
t_swap        | s  | derived | t_stop + t_cool_hold + t_valve + 2 * n_couple * t_couple + 2 * n_mount * t_bolt + t_lift + t_align + t_purge | the mechanical exchange, end to end: stop, cool, isolate, part sixteen couplings, undo four bolts, lift out, lift in, seat, do up four bolts, make sixteen couplings, fill and purge
t_service     | s  | derived | t_swap + t_bringup                      | the whole service event as an operator experiences it, from the machine still running to the replacement passing rung ten. 085 owns the second half and this blueprint owns the first
t_service_h   | hr | derived | t_service                               | the same, in the unit somebody plans a shift around
t_shift       | hr | given   | 8.0                                     | a working shift, which a service event has to fit inside or it becomes a two-day job and the installation is down overnight
f_swap_of_svc | 1  | derived | t_swap / t_service                      | the share of a service event that is hands on the machine rather than the machine testing itself
```

## Constraints

```constraints
C-019-1 | F_mount_shock < F_corner_rating | load at a mount point under transit shock must stay inside what a corner block will take. The static case is trivial; the shock case is what actually sizes the block
C-019-2 | n_mount_rigid == 3              | three points constrain a rigid body. A fourth rigid point does not add stiffness, it adds a preload that varies with temperature and finds the weakest seal
C-019-3 | travel_compliant > disp_frame   | the compliant mount must allow more motion than the frame and the cube will ever have between them, or the difference is transmitted into 017's seals
C-019-4 | V_spill_life < V_makeup         | fluid lost over the installation's life, in couplings alone, must stay under the make-up volume 027 provides
C-019-5 | n_orient == n_face              | every face is a candidate mounting face and each must be checked for the vent condition. Asserted so that an orientation is not silently dropped from the analysis
C-019-6 | d_bolt * 3 < L_corner           | a bolt and its clearance must fit within a corner block with material left around it
C-019-7 | t_service_h < t_shift          | a service event must fit inside one working shift, or the installation is down overnight and a cube swap becomes a two-day job. It comes to a little over three hours, and two of those are 085 testing the replacement rather than anybody touching it
C-019-8 | t_cool_hold < t_valve          | the cube must be cool enough to handle before the isolation valves are even shut. Asserted in the direction of alarm: it comes out at seventeen seconds against two minutes, so the cooling hold costs nothing in practice, and the reason is that a machine this small holds ten kilojoules above ambient while its coolant carries away nearly two thousand watts
C-019-9 | tau_cube > t_stage             | the whole machine's thermal time constant must be long compared with one pipeline stage. If it were not, the cube would cool measurably between tokens and 026's walking hot spot would be a temperature cycle rather than a ripple
C-019-10 | f_swap_of_svc < 0.5           | less than half a service event may be a person with their hands on the machine. The rest is the replacement proving itself, which is time somebody can spend elsewhere -- and if this ever inverts, the procedure has grown manual steps that should be looked at
```

## What is still open

**Which orientations are actually permitted has not been worked out.** The rule
is written — an outlet corner must be the highest point — and the six cases have
not been enumerated against `010`'s parity assignment. It is twenty minutes of
work and it may eliminate an orientation somebody wanted.

**The step times are chosen and not measured.** Every one of them is a `given`,
which is the honest label: nobody has done this with a stopwatch, and until
somebody has, `t_service` is a design intention rather than a fact about the
world. What has changed is that it is now a sum of nine things a person can argue
with one at a time, rather than one number nobody could take apart. The one that
is not a guess is the cooling hold, which comes out of the machine's own heat
capacity and its own thermal resistance.

**A cube with a bonded spout cannot be removed at all.** `066` makes the output
face permanent, which means the cube and whatever it is bonded to are one object
for the purposes of everything above. `069a` mostly rescues this by bonding the
cube to a small translation die whose own far side is detachable, but the mount
in this blueprint assumes a cube alone and has not been redrawn for the pair.
