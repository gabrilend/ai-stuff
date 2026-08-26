# 056 — One outward surface, six times

```meta
phase  | 8
issues | 801
```

The identical outward interface every face carries, and the populations that turn
one of them into a storage line, an output tube or a host link.

## Why this is worth a blueprint

`008` entry 4 records the conflict in the original page: six storage lines *and*
one face spent on an output tube is seven faces' worth of purpose on six faces.

The resolution is that a face's outward surface is not committed in silicon. It
is a field of pads with a defined electrical character, and what is soldered to
it is an assembly decision. **One face assembly design, built six times** — two
designs would mean two mask sets, two qualifications, two yield curves and two
spares inventories.

## The zoning trade

```drawing
one port field, looking inward [not-dimensioned]

   ┌───────────────────────────────────────────┐
   │ ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪ │  ▪ perimeter zone:
   │ ▪ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ▪ │    coarse pitch, power
   │ ▪ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ▪ │    and differential pairs,
   │ ▪ ░░░░░░░░░ the fine zone ░░░░░░░░░░░░░ ▪ │    routed through the cold
   │ ▪ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ▪ │    plate's via islands
   │ ▪ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ▪ │
   │ ▪ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ▪ │  ░ fine zone: bondable
   │ ▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪▪ │    pitch, used only by a
   └───────────────────────────────────────────┘    spout, routed to the cage
```

**Two routes, not one.** The perimeter zone reaches the interposer through
`014`'s sixteen via islands. The fine zone does not — a bonded spout's conductors
go to the cage, through the face, which is a completely different path. Getting
this wrong is discovered at assembly, so both are drawn.

**The fine zone is on all six faces and five will never use it.** That is the
cost of one part number, and it is stated rather than hidden: a bondable pitch
across a fifty-two millimetre square is a process step and a yield term on every
face whether or not anything is bonded to it.

## The populations

| population | zone used | what it is |
|---|---|---|
| storage line | perimeter | power and `057`'s pairs |
| host link | perimeter | power and fewer pairs |
| cabled spout | perimeter | power and all the pairs |
| byte-mode spout | fine, at microbump pitch, plus perimeter for power | `068` |
| bonded spout | fine, at bond pitch | `066` |
| blank | power only | valid, and cheaper |

## Symbols

```symbols
p_port_coarse | um | given | 250.0 | pitch of the perimeter zone, a detachable land grid
w_perimeter   | mm | given | 2.0   | width of the perimeter zone on each side. Four millimetres was the first sketch and it costs the fine zone a quarter of its area, which halves the pane in 062 -- and the perimeter needs a few hundred conductors against the several thousand positions two millimetres already gives it
n_pair_line   | 1  | given | 64    | differential pairs one storage line uses
n_pad_power   | 1  | given | 96    | pads carrying the face's supply and its return
n_pad_control | 1  | given | 32    | pads for management, telemetry and the interlock
i_pad_port    | A  | given | 0.30  | current one perimeter pad carries

A_port        | mm^2 | derived | A_plate                                    | the whole outward surface
A_perimeter   | mm^2 | derived | A_plate - (L_plate - 2*w_perimeter)^2      | area of the perimeter zone
A_fine        | mm^2 | derived | (L_plate - 2*w_perimeter)^2               | area of the fine zone
n_pad_perim   | 1    | derived | A_perimeter / p_port_coarse^2       | positions in the perimeter zone
n_port_conductor | 1 | derived | 2*n_pair_line + n_pad_power + n_pad_control | conductors that must reach the interposer through 014's via islands
I_port_max    | A    | derived | n_pad_power / 2 * i_pad_port               | current the power pads will carry, half of them being return
f_fine_unused | 1    | derived | (n_face - 1) / n_face                     | share of the fine zones that will never be bonded to anything, which is the price of one part number
n_pop         | 1    | given | 6                                           | populations this field supports
```

## Constraints

```constraints
C-056-1 | n_port_conductor <= n_island_pad | every conductor the perimeter zone needs must fit through the sixteen via islands in the cold plate. If this fails, either the islands grow and take more wetted area or the port field carries less
C-056-2 | I_port_max >= I_face_supply      | the power pads must carry the current one face brings in, with the pad count rather than the pad rating being what is adjusted
C-056-3 | n_pad_perim > n_port_conductor * 2 | the perimeter zone must have at least twice the positions its conductors need, because a differential pair wants a ground beside it and a land grid wants alignment features
C-056-4 | A_fine >= A_spout_need           | the fine zone must be large enough for the widest spout grade in 063
C-056-5 | A_perimeter + A_fine ~= A_port   | the two zones must account for the whole surface
C-056-6 | f_fine_unused > 0.5              | most of the fine zones will never be used. Asserted in the direction of alarm, because it is the cost of building one part six times and somebody optimising should meet it as a number rather than as a surprise
```

## What is still open

**The fine zone's cost is stated and not quantified.** A bondable pitch across
every face is a process step and a yield term on all six; `083` should be
carrying it and does not. If it turns out expensive, the alternative is two face
designs, and `C-056-6` is the line that would start that argument.

**Nothing says what a blank population looks like mechanically.** A face with
only power on it still has to seal, still has to conduct heat, and still has to
present a flat surface to whatever the cube is bolted to.
