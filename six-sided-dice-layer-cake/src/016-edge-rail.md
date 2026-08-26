# 016 — The edge rail

```meta
phase  | 2
issues | 204
```

One part, made twelve times. It occupies the square strip along one edge of the
cube, spans the gap between two corner blocks, and carries two channels that
never meet.

```drawing
edge rail cross-section, looking along the edge

        ├──────── [w_rail] ────────┤
        ┌──────────────────────────┐   ─┬─
        │  ╭────────────────────╮  │    │
        │  │      supply        │  │  [h_rail_chan]
        │  ╰────────────────────╯  │    │
        │  ────────────────────────│  [t_rail_web]
        │  ╭────────────────────╮  │    │  [w_rail]
        │  │      return        │  │  [h_rail_chan]
        │  ╰────────────────────╯  │    │
        └──────────────────────────┘   ─┴─
           ├── [w_rail_chan] ──┤
           the two are stacked, not side by side: a rail is
           four millimetres across and the flow needs width
```

Both networks reach every edge. That is what gives `022` the freedom to run each
face's microchannel field in whichever direction suits it, and `023` requires
that opposite faces run theirs perpendicular so no rail pair carries two full
face loads.

## The rail is not transparent, and that is a finding

The intention was a manifold twenty times more permissive than the load it
supplies, so that the flow distribution in `024` would be insensitive to how well
it was built. **A four millimetre rail cannot do it.**

A rail feeds one face's microchannel field, which wants a sixth of the machine's
flow — nearly ten cubic centimetres a second. Fitting two channels and their
walls inside a four millimetre square leaves about four and a third square
millimetres each, so the velocity is over two metres a second, the flow is
turbulent, and a rail loses something near five kilopascals against the field's
eleven.

That is a **third** of the loop, not a twentieth. Three ways out were available
and only the third is honest. Widening the rail pushes the face plate below the
die block and the cube has to grow. Reducing the flow means a larger coolant
temperature rise, which is affordable but buys less than it costs elsewhere. Or
the claim is withdrawn and `024` solves the network properly instead of leaning
on a manifold that is not negligible.

The claim is withdrawn. What actually balances this network is the parity
topology in `023` — every point of the supply mesh within one edge of a feed —
and not the rails being invisible. That was always the stronger argument; it was
simply not the one being relied on.

## The rail is also the frame

Twelve rails are the cube's structure and the face plates are panels between
them. `018` will find that the rails carry most of the bending load, and `013`'s
tolerance stack closes around them rather than around the plates. The second
moment of area is published here for that reason and not because anything in
phase 2 uses it.

## Symbols

```symbols
w_rail_chan   | mm   | given | 3.20  | width of one channel in a rail, across the rail's square section
h_rail_chan   | mm   | given | 1.35  | height of the same; the two channels are stacked and this is what is left after the walls
t_rail_web    | mm   | given | 0.50  | metal between the supply channel and the return channel
t_rail_wall   | mm   | given | 0.40  | metal between a channel and the outside of the rail
K_rail_ends   | 1    | given | 1.50  | entrance and exit loss coefficients for one rail, summed

A_rail_chan   | mm^2 | derived | w_rail_chan * h_rail_chan                  | cross-section of one channel in a rail; there are two, one supply and one return
L_rail        | mm   | derived | L_cube - 2 * L_corner                      | length of a rail between the two corner blocks it joins
D_rail        | mm   | derived | 2 * w_rail_chan * h_rail_chan / (w_rail_chan + h_rail_chan) | hydraulic diameter of a rectangular rail channel
n_rail_chan   | 1    | derived | 2 * n_edge                                 | rail channels in the machine, supply and return on every edge
Q_rail        | m^3/s| derived | Q_total / n_face                           | volumetric flow along one supply rail: a rail feeds one face's field, and there are six of those
v_rail        | m/s  | derived | Q_rail / A_rail_chan                       | velocity in a rail channel
Re_rail       | 1    | derived | rho_water * v_rail * D_rail / mu_water     | Reynolds number in a rail; expected to be transitional, which is the awkward regime
f_rail        | 1    | derived | 0.316 / Re_rail^0.25                       | Darcy friction factor from the Blasius correlation, valid to about Re of one hundred thousand
dp_rail       | Pa   | derived | (f_rail * L_rail / D_rail + K_rail_ends) * rho_water * v_rail^2 / 2 | pressure lost along one rail including its ends
f_rail_loss   | 1    | derived | dp_rail / dp_loop                          | that loss as a fraction of the whole loop's
V_rail_wet    | mm^3 | derived | n_rail_chan * A_rail_chan * L_rail         | fluid standing in all twenty-four rail channels
I_rail        | mm^4 | derived | w_rail^4 / 12 - 2 * A_rail_chan^2 / pi     | second moment of area of a rail about a face-parallel axis, the square section less its two bores
m_rail_one    | kg   | derived | w_rail^2 * L_rail * f_solid_rail * rho_ss  | mass of one rail
```

## Constraints

```constraints
C-016-1 | f_rail_loss < 0.30                                  | a rail loses about a third of the loop's pressure. The first attempt asked for a twentieth, which a four millimetre rail cannot deliver at this flow, so the claim was withdrawn rather than the number adjusted quietly -- and 024 must therefore solve the network instead of assuming the manifold is invisible
C-016-2 | 2 * h_rail_chan + t_rail_web + 2 * t_rail_wall <= w_rail | two stacked channels, the web between them and the wall around them must fit across the rail's square section
C-016-3 | p_burst_web > p_proof                               | the web between the supply and return channels must hold proof pressure as a flat plate, for the same reason 015's chamber wall must
C-016-8 | w_rail_chan + 2 * t_rail_wall <= w_rail            | and the channels must fit across the other axis too
C-016-4 | Re_rail > 2300                                      | the rail is expected to be turbulent or transitional, which is the regime the Blasius correlation above assumes. If this fails, the friction factor is being computed with the wrong formula and the pressure drop is wrong by tens of per cent -- which, since the rail is four per cent of the loss, still barely matters, and asserting it is how that stays true rather than becoming an assumption
C-016-5 | Re_rail < 100000                                    | and under the upper limit of the same correlation
C-016-6 | v_rail < v_erosion_max                              | velocity must stay under what the material tolerates before flow erosion shortens the life in 086
C-016-7 | n_rail_chan == 2 * n_edge                           | every edge carries exactly one supply and one return, which is what 023's two-network topology requires
```

## Symbols this needs and does not own

```symbols
p_burst_web   | Pa | derived | 2 * sigma_ss_y * t_rail_web^2 / (3 * w_rail_chan * h_rail_chan) | pressure the web between a rail's two channels will take as a flat plate before yielding
```

## What is still open

**The rail is transitional and that is the least comfortable regime.** Reynolds
number lands near two thousand, where the laminar and turbulent correlations
disagree by tens of per cent and neither is trustworthy. `024` must say which it
used and how much the answer would move under the other — and because the rail is
four per cent of the loop's loss, the honest conclusion is likely to be that it
does not matter, which is itself worth writing down rather than leaving as a
thing nobody checked.

**The rail is sized by what fits, not by what the flow wants.** Three point two
by one point three five is the largest channel a four millimetre rail will hold
with walls that survive proof pressure, and the velocity that results is what it
is. `024` inherits that rather than specifying it, which is the wrong way round
and is only acceptable because the alternative — growing the rail — grows the
cube.
