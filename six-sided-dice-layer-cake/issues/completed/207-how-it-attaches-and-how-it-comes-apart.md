# 207 — How it attaches, and how it comes apart

Produces `src/019-mount-and-service-frame.md`.

## Current behavior

**Done.** `src/019-mount-and-service-frame.md` exists, with the four rules: one
mechanical interface rather than six, couplings that part dry, no assumption
about which way is up, and a fourth mount point that is compliant because three
points constrain a rigid body and a fourth adds a temperature-varying preload
that finds the weakest seal.

The loads are undemanding -- under a hundred and forty newtons per mount even at
fifty times gravity -- and the bolt came down from M4 to M3 because three
diameters of clearance in a twelve millimetre corner block is exactly twelve
millimetres for an M4 and leaves nothing around it.

The blueprint says plainly that nothing inside a cube is serviceable and that
service means replacing the whole thing.

**Two things are not done.** Which mounting orientations are actually permitted
has not been enumerated against the parity assignment -- the rule is written and
the six cases are not checked, and it may eliminate an orientation somebody
wanted. And the service time is carried as a `target` rather than a derivation,
which the checker reports, because it cannot become one until `1205` writes a
procedure that could be timed.

## Intended behavior

**How a one and a half kilogram sealed cube with a live coolant loop through it,
six connectors on six different faces, and no serviceable interior, is attached to
the world and later removed from it.**

This is a real design problem and not a formality, because the cube's shape is
hostile to every convention. A card slides out of a slot. A socketed processor
lifts off a board. **A cube cannot be pulled in any direction without
disconnecting five faces first**, and two of those connections are carrying water.

### What has to be true

**It has one mechanical interface, not six.** Loads go into the four corner blocks
of one chosen face, which `203` already makes the stiffest points on the object.
The other twenty faces' worth of connectors carry signal and must carry no load
at all; a port field taking mechanical stress is a port field that fails in the
field.

**The coolant connects and disconnects dry.** Four inlets and four outlets, each
a self-sealing quick coupling that closes both halves when parted. The residual
volume in a coupling — the drop that escapes each time — times eight, times the
number of service events in the machine's life, is a number that belongs in this
blueprint and in `027`'s make-up volume.

**Gravity is not assumed.** The cube has six equivalent faces and no natural up.
Whichever face is mounted, the coolant loop must purge air from all twelve rails,
which means the highest point in *any* mounting orientation must have a vent path.
Eight corner blocks, four of which are already outlets — the vent goes there, and
`308` has to know which orientations are permitted.

**Thermal expansion of the mount is not the cube's problem.** The frame is
stainless, the cube's exterior is mostly stainless rails, and the mounting must
allow the difference without transmitting it into the seals in `205`. Three points
constrain a rigid body; four bolts over-constrain it. The fourth point must be
compliant.

### What service actually means

Nothing inside a cube is serviceable. There are no field-replaceable parts, no way
to reach a die, and no way to reopen a bond. **Service means replacing the whole
cube**, and this blueprint exists to make that a twenty minute job rather than a
morning.

The blueprint should say so plainly, because a specification that implies
serviceability it does not have is worse than one that admits the truth. `086` is
where the consequence lands: with no repair path, the reliability target has to be
met by the part rather than by maintenance.

## Symbols this must publish

Bolt pattern and thread. Load per mount point, static and under the shock and
vibration levels this must survive in transit. The compliant point's allowed
travel. Coupling residual volume and total spillage per service event. Vent path
geometry. Permitted mounting orientations. Frame mass. Service time as an
estimate, flagged as such.

## Constraints this must assert

- Load at any mount point stays under the corner block's rating from `203`,
  including shock.
- No load path passes through a port field or a face plate seal.
- In every permitted orientation, at least one outlet corner is the highest point
  of the coolant circuit.
- Frame-to-cube differential expansion over the operating range stays within the
  compliant point's travel.
- Total spillage over the service life stays under the make-up volume in `027`.

## Suggested implementation steps

1. Choose the mounting face and draw the bolt pattern on `203`'s blocks.
2. Work the static and shock loads and check the corner blocks.
3. Pick the coupling and get its residual volume from its data sheet, entered as
   `measured` with the source named.
4. Enumerate the permitted orientations and check the vent condition in each. This
   is the step most likely to eliminate an orientation somebody wanted.
5. Make the fourth mount point compliant and size its travel from `206`.
6. Write the paragraph admitting there is no field repair.

## Blocks

`308`, `1205`, `1206`, `1301`.

## Blocked by

`201`, `203`, `205`.

## Related documents

`007` on why the bonded output grade makes this worse — a cube bonded to another
cube cannot be removed at all. `009` entry B3 is the same question from the other
side.
