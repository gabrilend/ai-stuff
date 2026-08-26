# 069b — The cube as memory

```meta
phase  | 9
issues | 910
```

The idea arrived from outside the design: *it'd be RAM for a normal computer to
use and read from.* It is the most useful thing anybody has suggested doing with
the spout, and it reframes the machine — **a large, fast, self-populating block
of memory that happens to be able to think about its own contents.**

## What makes it plausible

Three properties the design already has, none of them added for this.

**The core is one flat address space** (`038`) with no caches above it and no
coherence to maintain (`039`). A host reading it does not have to be told about
anybody else's copy, because there are none.

**The pane is already a window.** `038`'s aliasing register says which part of the
core the spout sees, and moving it is one store. That is exactly what a memory
expander needs.

**The cube pays almost nothing.** A pane read is tens of nanoseconds against a
token's hundreds of microseconds.

## What has to be added

**A request path back.** Everything else in phase 9 is one-way. Memory needs the
host to name an address, which means the translation unit must be able to move
the pane window — a small write into `038`'s control region. It goes over the
port field's control group rather than a reverse spout channel, because the
control group already exists and a reverse channel would put a second signalling
direction into an interface `064` deliberately made unidirectional.

**A latency budget.** Move the window, wait for the core read, cross the pane,
deskew, buffer, answer. Each is small; summed, it is **hundreds of nanoseconds**.
So this is not main memory. It is a large second tier, and the blueprint says so
plainly rather than letting a reader infer otherwise.

**An access rule against the generator.** A host reading a region the faces are
writing is `039`'s third sharing case. **Restrict host reads to the weight
region**: it is most of the capacity, it is genuinely immutable while a model is
loaded, and it needs no locking at all.

## What it is actually good for

Specific, because *it can be RAM* invites the wrong comparison.

- **Loading a model from the host side**, by writing rather than streaming from
  drives — which removes eighty drives from an installation.
- **Reading a model back out**, for checkpointing after `076a`'s adapter
  training. The one that matters if training is used.
- **Sharing a model with a host process** that wants to inspect it.
- **A second cube reading the first's weights**, which is the ganging case
  without a ganging protocol.

## Symbols

```symbols
t_win_move    | ns | given | 200.0   | to move the pane window: a control write over the port field and its acknowledgement
t_rx_pipe     | ns | given | 40.0    | deskew, reorder and buffer at the far end
n_host_req    | 1/s | given | 1.0e5  | host requests a second in ordinary use of this mode
f_host_region | 1 | given | 0.49     | share of usable capacity exposed to a host: the weight region, which is immutable while a model is loaded

t_mem_read    | ns | derived | t_win_move + t_pane_fill + t_pane_empty + t_rx_pipe | latency for one host read, end to end
C_host_vis    | GB | derived | C_core_usable * f_host_region     | capacity a host can see
B_host_seq    | bit/s | derived | n_pane_bit / t_mem_read | sustained rate on sequential reads, one pane at a time
t_cube_per_req| s | derived | t_pane_fill                         | core time one host request costs
f_cube_cost   | 1 | derived | n_host_req * t_cube_per_req         | share of the core's time spent serving a host at the stated request rate
t_load_host   | s | derived | C_weights / B_host_seq              | how long loading a model through this path takes, against 057's thirty milliseconds from drives
ratio_dram    | 1 | derived | t_mem_read / t_dram_ref             | how much slower than a host's own memory, which is the comparison that decides what this is for
t_dram_ref    | ns | measured | 80.0 | latency of a host's own attached memory, as the comparison
```

## Constraints

```constraints
C-069b-1 | f_cube_cost < 0.01          | serving a host at the stated request rate must cost the core under a hundredth of its time, so that memory mode never visibly slows generation
C-069b-2 | C_host_vis < C_weights * 1.05 | what a host can see must be the weight region and not much more, which is the access rule expressed as a capacity rather than as a promise -- and is what removes the need for any locking
C-069b-3 | ratio_dram > 2              | this must be slower than a host's own memory. Asserted in the confirming direction, because the honest positioning is a large second tier and a blueprint that let somebody believe otherwise would be worse than one that said nothing
C-069b-4 | t_load_host < t_load_max * 100 | loading a model this way must be within two orders of magnitude of loading it from drives, or removing eighty drives from an installation is not a trade anybody would take
C-069b-5 | t_mem_read > t_pane_fill      | a host read cannot be faster than the core takes to fill the pane, which is the floor everything else sits on
```

## What is still open

**The bandwidth cost of this mode is not in `055`.** That blueprint budgets the
spout at one pane a millisecond as an ordinary operating rate. A host using this
as memory takes a hundred thousand a second, which is a hundred times more, and
`C-055-5` would be the first thing to notice. **Neither blueprint has reconciled
with the other.**

**Nothing says what happens if a host reads outside the weight region.** The
access rule is a capacity constraint here and there is no mechanism enforcing it,
which is the same gap `038` records for out-of-range addresses generally.

**Writing is not specified at all.** Loading a model from the host side is listed
as a use and everything above is a read path. A write path needs `039`'s ordering
contract extended to a device outside the cube, and that is not written.
