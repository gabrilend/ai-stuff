# 051 — Seven millimetres of wire

```meta
phase  | 7
issues | 702
```

## The two budgets, and which one binds

A face's inward surface meets the cage across a square patch the width of the
cavity. At a twenty micron pitch that is over five million positions; spend two
fifths on power and ground and three million signal conductors remain.

**Counting pads gives an absurd answer.** Three million conductors at a couple of
gigabits each is petabits a second — hundreds of times what the memory behind it
can supply.

**Counting picojoules gives the real one.** At a tenth of a picojoule a bit, the
same traffic is hundreds of watts on one link. **Power binds this interface, by
more than an order of magnitude**, and a reader who sizes it by pad count will
size it wrong in the same way a reader who counts wires sizes the spout wrong.

So the link is provisioned at the bandwidth the core can actually deliver, with
headroom, and the pads left over become spares.

## The circuit

Single-ended, low swing, no equalisation, no clock recovery. Seven millimetres in
a controlled impedance environment is short enough that all three can be omitted,
and each omission is area and power not spent. **The reach over which those
omissions hold is stated**, so that nobody reuses this circuit somewhere longer —
`067`'s cabled spout is where they all come back.

## Source-synchronous, per tile

Distributing one launch edge across the whole interface costs a large fraction of
a cycle. So the interface is tiled, each tile forwards its own strobe with its
own data, and the receiver deskews per tile. **The tiling matches `063`'s** so
that one deskew design serves both the link and the spout.

## Redundancy

Five million connections, made once, never repairable. Some fail at assembly and
some later. **A link with no spares makes cube yield a function of five million
independent bonds**, which is a yield of zero, so spares and a remap are part of
the interface rather than an afterthought.

## Symbols

```symbols
d_radial_pad   | um | given | 20.0   | pitch of the radial interface's pad array
f_radial_power | 1  | given | 0.40   | share of positions given to power and ground, which 030 needs for the core's inward supply
f_radial_spare | 1  | given | 0.05   | share held as spares against bonds that fail
r_pad_bit      | bit/s | given | 2.0e9 | bits a second one conductor carries: a low swing over a short reach, with no equalisation
f_medium_link  | 1  | given | 0.50   | how fast a signal travels in this medium, as a fraction of the speed of light
L_reach_max    | mm | given | 12.0   | the furthest this circuit is valid over. Beyond it, equalisation and clock recovery come back and it becomes 067's problem
V_link_min     | V  | given | 0.45   | the least swing that keeps the receiver's noise margin across this interface, which 029 reads
w_tile_link    | 1  | given | 4096   | conductors in one source-synchronous tile
e_link_bit_d   | pJ/bit | measured | 0.10 | energy to move one bit across the interface, driver and receiver together

L_radial       | mm | derived | L_cavity                                  | edge of the square patch where a face meets the cage
n_radial_col   | 1  | derived | floor(L_radial / d_radial_pad)     | pad columns across it
n_radial_pad   | 1  | derived | n_radial_col^2                            | positions in the array
n_radial_sig   | 1  | derived | n_radial_pad * (1 - f_radial_power - f_radial_spare) | conductors carrying data
n_radial_spare | 1  | derived | n_radial_pad * f_radial_spare             | conductors held in reserve
B_link_pads    | bit/s | derived | n_radial_sig * r_pad_bit                | what the pad count alone would permit
P_link_pads    | W  | derived | e_link_bit_d * B_link_pads                | and what that would cost, which is the number that shows power binds
B_link_used    | bit/s | derived | B_core                                  | what the link is actually provisioned for: everything the memory behind it can deliver
P_link_used    | W  | derived | e_link_bit_d * B_link_used               | and what that costs on one link at full rate
bind_ratio     | 1  | derived | B_link_pads / B_link_used                 | how much more the pads would have allowed than the power budget does
n_tile_link    | 1  | derived | n_radial_sig / w_tile_link                | source-synchronous tiles across the interface
t_flight       | s  | derived | L_link / (c_light * f_medium_link)        | one-way flight time over the link
t_link_rt      | s  | derived | 2 * t_flight + t_access + t_wait_face + t_proto | round trip from a face issuing a read to the first data arriving: two flights, the array's access, the worst arbitration wait, and the protocol's own overhead
t_proto        | s  | given | 2.0e-9 | fixed protocol overhead in a round trip: framing, decode and the crossing into the cage's clock domain
```

## Constraints

```constraints
C-051-1 | B_link_used <= B_link_pads    | the link must carry everything the core can deliver, which the pad count permits many times over
C-051-2 | bind_ratio > 10               | and the pads must permit at least an order of magnitude more than the power budget allows, which is the statement that power is what binds here. Asserted so that a reader who sizes this interface by counting pads finds out from the checker rather than from a thermal failure
C-051-3 | P_link_used ~= P_link         | the power one link costs at full rate must be the figure 020's budget carries
C-051-4 | V_link >= V_link_min          | the swing 029 chose must exceed what this interface's noise margin needs. Each blueprint reads the other's number, so neither may move alone
C-051-5 | L_link < L_reach_max          | the link must be inside the reach where equalisation and clock recovery can be omitted
C-051-6 | n_radial_spare > n_radial_sig / 100 | there must be at least one spare per hundred signal conductors, because a link with none makes cube yield a function of five million independent bonds
C-051-7 | n_tile_link * w_tile_link <= n_radial_sig | the tiles must fit the conductors available
```

## What is still open

**The spare fraction is a `given` and `083` should be setting it.** Five per cent
is a plausible number and the yield model that would justify it does not exist,
so `C-051-6` currently checks a guess against a rule of thumb.

**Nothing says how a spare is mapped in.** The conductors are bonded; the remap
has to be electrical, which means a small switch on every tile and a way of
finding out which conductors failed. `084`'s test access is where that would
live and it does not mention the link.

**The flight time assumes a medium.** Half the speed of light is right for a
microstrip and wrong for a dense pillar array, and nobody has extracted the real
figure.
