# 057 — The line to the drives

```meta
phase  | 8
issues | 802
```

## What it is for, which bounds how good it needs to be

The storage lines exist to fill the core once. **After that no weight a face
reads during a token comes from a drive** — every one comes from the middle.

That sentence sets the standard for everything below. A line that takes thirty
milliseconds instead of six is a line nobody notices. A line that costs two
hundred watts is one everybody notices. **The lines are sized for cost and heat,
not for speed.**

## The shape

A line is not one device: a controller on the port field, a cable, and a shelf of
drives. The drive count is a **deployment choice with a load time attached**
rather than a requirement, and the blueprint presents it that way — sixteen
drives a line gives tens of milliseconds, one drive a line gives seconds, and
against a machine that then runs for weeks the difference is nothing.

## Five lines, six slices

A cube with an output tube has one fewer line than it has faces. The sixth slice
arrives over another line and is **relayed through the core**, which costs a fifth
more load time and nothing else. It is the only case where a storage line's data
is destined for a face other than its own, and it is specified rather than left
to be discovered.

## Symbols

```symbols
n_line_pop    | 1 | given | 5      | storage lines populated on a cube that also has an output tube
n_drive_line  | 1 | given | 16     | drives behind one line
r_drive       | bit/s | measured | 1.28e11 | bits a second one drive sustains on a long sequential read
r_pair_line   | bit/s | given | 3.2e10 | bits a second one differential pair carries on this link
L_cable       | mm | given | 1000.0 | reach from the port field to the drive shelf
e_line_bit    | pJ/bit | measured | 5.0 | energy to move one bit over the line, both ends included

B_line        | bit/s | derived | n_pair_line * r_pair_line       | what one line's pairs carry
B_drives      | bit/s | derived | n_drive_line * r_drive          | what the drives behind it supply
B_feed        | bit/s | derived | n_line_pop * min(B_line, B_drives) | aggregate into the machine
t_load        | s | derived | C_weights * 8e9 / B_feed            | time to fill the core
t_load_relay  | s | derived | t_load * n_face / n_line_pop        | and with the sixth slice relayed through the core over one of the five
P_line        | W | derived | e_line_bit * B_feed                 | what the lines cost while they are running, which is only during a load
n_drive_total | 1 | derived | n_drive_line * n_line_pop           | drives an installation has to provide
t_load_min    | s | derived | C_weights * 8e9 / (n_line_pop * r_drive) | load time with a single drive on each line, which is the other end of the deployment table
```

## Constraints

```constraints
C-057-1 | B_line >= B_drives            | the line must not be narrower than the drives behind it, or the pairs are the restriction and the drive count buys nothing
C-057-2 | t_load_relay < t_load_max     | filling the core, including relaying the sixth slice, must be under the stated ceiling
C-057-3 | n_pair_line * 2 <= n_port_conductor | the pairs must fit in what 056 routes through the via islands
C-057-4 | P_line < P_port_burst       | the lines must fit inside the transient port allowance. They do not fit inside the steady one and should not have to: a load runs them flat out for tens of milliseconds and then they are idle until the machine is next power-cycled
C-057-7 | P_line * t_load_relay < E_burst_max | and the energy of a whole load must be small enough for 026's thermal masses to absorb without the coolant hearing about it
C-057-5 | t_load_min < 60               | even at one drive a line the machine must load in under a minute, which is what makes the drive count a deployment choice rather than a requirement
C-057-6 | L_cable < L_reach_line        | the cable must be inside the reach the chosen physical layer supports
```

## Symbols this owns and needs

```symbols
E_burst_max   | J | given | 20.0   | the most energy a transient may deposit in the face assemblies before it stops being absorbed by their thermal mass and starts being a load the coolant sees
t_load_max    | s | given | 0.100  | the longest filling the core may take. A tenth of a second is what somebody starting a machine will not notice; the design comes in well under it
L_reach_line  | mm | given | 3000.0 | reach of the adopted serial standard at this rate, from its own specification
```

## What is still open

**No physical layer is named.** The blueprint says an existing standard should be
adopted rather than one specified, and does not say which. Every number here —
the rate a pair carries, the reach, the energy a bit costs — is a figure from a
standard nobody has chosen, which makes them plausible rather than sourced.

**The controller is not designed.** Something on the port field turns a serial
link into transfers into the core, and it is not in any blueprint. It is small,
and it is the only piece of logic in this machine that speaks to the outside
world in somebody else's protocol.
