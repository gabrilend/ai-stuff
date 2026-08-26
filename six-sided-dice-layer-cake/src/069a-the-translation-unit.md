# 069a — The thing on the other end

```meta
phase  | 9
issues | 909
```

The spout emits a pane on one edge. **There is no computer that accepts that.** So
between the cube and anything else sits a companion part fluent in the pane on
one side and in an ordinary interface on the other.

## Why this shape

Putting the translation inside the cube would mean choosing, at silicon design
time, which host interface the machine speaks — and host interfaces change every
few years while a cube takes years to build.

Outside, **the cube is built once and adapters are built many times**, one per
thing worth attaching to. It also lets the cube's side of the interface be
exactly what suits a cube: maximally wide, minimally clever, no protocol, no
addressing, no negotiation. All the awkwardness lives in the part that is cheap
to respin.

```drawing
one translation unit [not-dimensioned]

   the cube               the unit                      the host
  ┌────────┐  pane   ┌─────────────────────┐        ┌───────────┐
  │ spout  │════════▶│ receive, deskew     │        │           │
  │ face   │  ~ns    │ reorder, un-invert  │───────▶│  whatever │
  │        │         │ buffer, [C_rx_buf]  │ slowly │  it speaks│
  └────────┘         │ protocol engine     │        │           │
                     └─────────────────────┘        └───────────┘
       │                                                   │
       └── free again immediately ─────────────────────────┘
```

## The interface that must not vary

`067` found the conflict and resolved it: **what leaves the core is identical in
every variant; what leaves the cube is not.** A cabled spout serialises a pane on
the face, so its cube-side signalling differs — but the pane window, the core, the
cage and the out-of-band state are the same. The requirement is on the **core
side**, and that is what makes one cube design serve every adapter.

## The funnel, which is the point

The spout bursts at petabytes a second. A host interface carries tens of
gigabytes. **The ratio is four or five orders of magnitude**, and the unit is a
funnel.

What it is for is not sustained throughput. It is that the cube can hand over any
window it holds **without spending any time on it**: one edge on the cube's side,
and however long the host needs on the other, during which the cube is generating.

## Symbols

```symbols
n_variant     | 1 | given | 4        | far sides specified: a memory fabric, a peripheral bus, a network interface, and another translation unit
d_rx_pane     | 1 | given | 4        | panes of buffering the unit holds
r_host_ref    | bit/s | measured | 4.8e11 | a fast host interface, as the reference far side
t_host_stall  | s | given | 1.0e-5   | the longest a host may stop accepting before the unit must be able to hold what has arrived
a_rx_lane     | um^2 | measured | 40.0 | receive circuit area per conductor: capture, deskew and a share of the reorder logic. It cannot be larger than the sending side's, because the far end meets the same pitch -- a hundred and forty was assumed before that was noticed, and made the unit a multi-die assembly rather than the cheap part

C_rx_buf      | MB | derived | C_pane_mb * d_rx_pane               | buffering the unit needs
C_rx_stall    | MB | derived | r_host_ref * t_host_stall           | what a host stall alone demands, which must be less
ratio_funnel  | 1 | derived | B_spout_burst / r_host_ref           | how much wider the cube's side is than the host's
t_host_core   | s | derived | C_core_usable / r_host_ref           | how long the host takes for a whole core, against the cube's tens of microseconds
f_cube_busy   | 1 | derived | t_core_out / t_host_core             | the share of that time the cube is occupied, which is the zero-cost claim as a number
A_rx          | mm^2 | derived | n_pane_bit / b1 * a_rx_lane       | die area the receive side needs, which is what makes this a die rather than a board
P_rx          | W | derived | e_pane_bit * B_spout_sust            | what receiving costs at the sustained rate
```

## Constraints

```constraints
C-069a-1 | C_rx_buf > C_rx_stall       | the buffer must cover a host stall, or panes are dropped and 069's retry becomes the normal case rather than the rare one
C-069a-2 | f_cube_busy < 0.001         | the cube must be occupied for under a thousandth of the time a whole-core handover takes. This is the zero-cost claim reduced to a number, and it is the property that justifies sixteen million wires -- not the throughput
C-069a-3 | ratio_funnel > 1000         | the cube's side must be orders of magnitude wider than the host's. Asserted so that a reader understands the unit is a funnel by design rather than an underperforming bridge
C-069a-4 | A_rx < A_reticle            | the receive side must fit one exposure, or the translation unit is itself a multi-die assembly and stops being the cheap part
C-069a-5 | P_rx < P_port_burst         | receiving must fit inside the same transient allowance the sending side uses
C-069a-6 | n_variant >= 2              | at least two far sides must be specified, or the whole argument for putting translation outside the cube is unexercised
```

## What is still open

**Only one variant is worked out.** The memory fabric row is `069b`; the
peripheral bus, the network interface and the cube-to-cube case are named and
nothing more. `C-069a-6` checks that more than one exists and cannot check that
any is finished.

**The receiving side's own skew is not budgeted.** `065` gets edges out of the
cube; gathering them across the far side is the same problem again and belongs
here, and is not here.

**Data conditioning leaks into the interface.** `064` inverts a tile's data when
that reduces switching and sends a bit saying so. Something must undo it, and it
is this unit — which means the core-side interface is not quite as protocol-free
as `062` claims.
