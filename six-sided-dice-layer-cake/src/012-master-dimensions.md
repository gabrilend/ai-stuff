# 012 — Master dimensions

```meta
phase  | 1
issues | 103
```

**The complete set of lengths in this machine that a person chose.** There are
eleven. Every other length in the project is an expression over these, over the
counts in `010`, and over the properties in `011`.

Three things follow from writing it this way. The cube can be resized by editing
one file and running `095`, which reports which constraint breaks first. No two
blueprints can disagree about a dimension, because a dimension lives in one
place. And a reader who wants to know what was actually **decided**, as opposed
to what followed, reads one page.

## The chain that produces the cube

Worth reading twice, because it runs in the opposite direction from the one
people expect. The cube is not sixty millimetres because sixty is a round number.

```drawing
what determines the size of this object [not-dimensioned]

   a transformer layer of the reference model      [C_layer_weights]
              │
              ▼   prefetch needs two of them resident at once
   a face slice must hold                          [C_face_slice]
              │
              ▼   at the areal density a logic die can manage
   a compute die must be                           [A_die]
              │
              ▼   four of them, two by two, plus a street
   the die block is                                [L_dieblock]
              │
              ▼   plus a seal ring on each side
   the face plate is                               [L_plate]
              │
              ▼   plus an edge rail on each side
   THE CUBE IS                                     [L_cube]
```

Change the reference model in `078` and the cube changes size. That is not a
weakness — it is the design being honest about what determined it.

## The eleven

```symbols
L_cube     | mm | given | 60    | outer edge length of the finished cube; follows from the four dimensions below it in the chain
t_face     | mm | given | 7.0   | one face assembly, outward surface to inward surface; the stack in 014 adds to just under this
t_cage     | mm | given | 3.0   | the switch shell lining the inside of the cavity, sized by the crossbar area in 037
w_rail     | mm | given | 4.0   | width of an edge rail, taken off each edge of each face plate; sized by the duct area 024 needs
L_die      | mm | given | 24.0  | edge of one compute die; two thirds of a reticle field, and half its area is the slice in 047
w_street   | mm | given | 1.0   | gap between two dies on a face, for placement tolerance and the seal ring
t_tier_si  | mm | given | 0.050 | thickness of one thinned memory tier; as thin as a tier can be handled
t_lamina   | mm | given | 1.617 | thickness of one cooling lamina between two tiers. It is what is left of the core's height once twenty-four tiers are laid in it, and the tier count came out of 034's capacity chain rather than being chosen
w_uchan    | mm | given | 0.150 | width of one microchannel in a face cold plate; this is the number that sets the heat transfer coefficient
h_uchan    | mm | given | 1.000 | depth of the same channel, limited by fin efficiency rather than by etching
w_ufin     | mm | given | 0.150 | wall between two microchannels, set by the plate's pressure rating in 017
```

## What follows

```symbols
L_cavity      | mm   | derived | L_cube - 2*t_face          | edge of the space the six faces enclose
L_core        | mm   | derived | L_cavity - 2*t_cage        | edge of the memory block the cage encloses
L_plate       | mm   | derived | L_cube - 2*w_rail          | edge of a face plate, once the edge rails are taken off
L_dieblock    | mm   | derived | 2*L_die + w_street         | edge of the four-die array on a face
w_seal        | mm   | derived | (L_plate - L_dieblock) / 2 | seal ring left around the die block on each side
t_tier_pitch  | mm   | derived | t_tier_si + t_lamina       | one repeating unit of the core stack
p_uchan       | mm   | derived | w_uchan + w_ufin           | pitch of the microchannel field
n_uchan       | 1    | derived | floor(L_plate / p_uchan)   | microchannels across one face cold plate
ar_uchan      | 1    | derived | h_uchan / w_uchan          | aspect ratio of one microchannel
A_plate       | mm^2 | derived | L_plate^2                  | area of one face plate
A_die         | mm^2 | derived | L_die^2                    | area of one compute die
A_core_side   | mm^2 | derived | L_core^2                   | area of one side of the core block, and of one tier
V_cube        | mm^3 | derived | L_cube^3                   | volume of the whole object
n_die         | 1    | derived | 4 * n_face                 | compute dies in the machine
A_die_total   | mm^2 | derived | n_die * A_die              | total compute die area, which 083 turns into a yield problem
```

## Constraints

```constraints
C-012-1 | L_dieblock < L_plate           | the four dies and their street must leave room for a seal ring on every side of the face plate
C-012-2 | L_plate < L_cube               | the face plate must fit inside the cube once an edge rail is taken off each side
C-012-3 | L_core < L_cavity              | the core must fit inside the cavity with the cage around it
C-012-4 | L_cavity > 0                   | the faces must enclose something; a cube thicker than it is wide is not a machine
C-012-5 | w_seal > 0                     | there must be a seal ring, which is only true if C-012-1 holds and is worth asserting separately because it is the thing that fails first when the die grows
C-012-6 | p_uchan > w_uchan              | a channel cannot be wider than its own pitch
C-012-7 | n_uchan * p_uchan <= L_plate   | the channels and their fins must fit across the plate they are etched into
C-012-8 | ar_uchan <= ar_uchan_max       | past this aspect ratio a fin stops carrying heat to its own tip and the extra depth is wasted material; the limit is derived in 022
C-012-9 | L_core ~= n_tier * t_tier_pitch | the two-chain check: the core's edge derived from the outside of the cube inward must equal the same edge derived from the memory stack outward. Two completely different arguments have to land on the same number, and this is what notices when they stop doing so
C-012-10 | w_seal >= w_seal_min          | the ring left around the die block must be at least what the compression seal in 017 needs
```

`C-012-9` is the single most valuable line in the blueprint set and is worth
reading slowly. `L_core` comes from the cube's outer edge, minus two face
thicknesses, minus two cage thicknesses — an argument entirely about the outside
of the object. `n_tier * t_tier_pitch` comes from how many memory tiers there
are and how thick each one is with its cooling plate — an argument entirely about
what is inside. Nothing forces them to agree. When somebody adds a tier, or
thickens a lamina, or shaves the cage, this is the line that fails.

`C-012-8` and `C-012-10` reach into blueprints that come later, and will report
as undefined until those exist. That is the correct behaviour and not a defect in
this file: the set is incomplete and the checker should say so.

## What is still open

**No tolerances.** Every one of the eleven is a point value. `009` entry X2.

**Whether sixty is right at all.** The chain above says the cube's size is set by
the size of a transformer layer in the reference model, and `009` entry B4 asks
whether that model is the right anchor. A model half the size would let the cube
shrink, and by how much is a question this file could answer in an afternoon and
nobody has asked.
