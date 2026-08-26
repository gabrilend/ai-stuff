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
t_service     | s | target | 1200  | seconds a cube swap takes, once the procedure in 1205 exists to be timed

m_mounted     | kg | derived | m_cube                                   | mass the frame carries
F_mount_static| N  | derived | m_mounted * g_accel / n_mount            | static load at one mount point
F_mount_shock | N  | derived | m_mounted * g_accel * g_shock / n_mount  | load at one mount point under transit shock
disp_frame    | mm | derived | (cte_frame - cte_ss) * dT_frame * L_cube | differential motion between frame and cube over the worst temperature difference
travel_compliant | mm | derived | 4 * (cte_frame + cte_ss) * dT_frame * L_cube | travel the compliant mount must allow, taken generously because the frame's own material is not settled
V_spill_event | mm^3 | derived | 2 * n_corner_in * V_coupling            | fluid lost in one service event, all eight couplings parted
V_spill_life  | mm^3 | derived | V_spill_event * n_service               | fluid lost over the installation's life
n_orient      | 1  | derived | n_face                                  | mounting orientations to check, one per face that could be the mounted one
```

## Constraints

```constraints
C-019-1 | F_mount_shock < F_corner_rating | load at a mount point under transit shock must stay inside what a corner block will take. The static case is trivial; the shock case is what actually sizes the block
C-019-2 | n_mount_rigid == 3              | three points constrain a rigid body. A fourth rigid point does not add stiffness, it adds a preload that varies with temperature and finds the weakest seal
C-019-3 | travel_compliant > disp_frame   | the compliant mount must allow more motion than the frame and the cube will ever have between them, or the difference is transmitted into 017's seals
C-019-4 | V_spill_life < V_makeup         | fluid lost over the installation's life, in couplings alone, must stay under the make-up volume 027 provides
C-019-5 | n_orient == n_face              | every face is a candidate mounting face and each must be checked for the vent condition. Asserted so that an orientation is not silently dropped from the analysis
C-019-6 | d_bolt * 3 < L_corner           | a bolt and its clearance must fit within a corner block with material left around it
```

## What is still open

**Which orientations are actually permitted has not been worked out.** The rule
is written — an outlet corner must be the highest point — and the six cases have
not been enumerated against `010`'s parity assignment. It is twenty minutes of
work and it may eliminate an orientation somebody wanted.

**`t_service` is a target and not a derivation**, which the checker will report.
It cannot become a derivation until `1205` writes the procedure that could be
timed, and it is here rather than absent because twenty minutes is the claim this
blueprint makes and a claim with no number is not one.

**A cube with a bonded spout cannot be removed at all.** `066` makes the output
face permanent, which means the cube and whatever it is bonded to are one object
for the purposes of everything above. `069a` mostly rescues this by bonding the
cube to a small translation die whose own far side is detachable, but the mount
in this blueprint assumes a cube alone and has not been redrawn for the pair.
