# 037 — Six askers, one store

```meta
phase  | 5
issues | 504
```

The switch between six radial links and the banked tiers behind them, and the
policy that decides who gets what.

## The requirement that shapes everything

**Any one face must be able to take the core's entire bandwidth when the others
are idle.**

This is not a performance nicety. During single-stream generation the sieve makes
exactly one face active at a time. If a face can only ever get a sixth of the
core, the six stages take six times as long as one would, and the sieve costs a
factor of six in latency — which is precisely the objection `008` entry 5 says is
wrong.

**The objection is only wrong if this crossbar is built this way.** Every other
blueprint in the project would continue to check if it were not. That is why the
requirement appears as a constraint in `034` as well as here.

The cost is a full-bandwidth path from every port to every bank, which is real
area and real power in the cage, and this blueprint publishes both rather than
hiding them.

## The three cases

```drawing
what the switch is actually doing [not-dimensioned]

   one asker        ────────────────────▶  give it everything
                                            the case that matters most

   six askers,      ──┬─┬─┬─┬─┬─────────▶  round robin at a coarse quantum
   disjoint regions   └─┴─┴─┴─┴─           the sieve's normal state

   six askers,      ──▶▶▶▶▶▶ one bank ──▶  should not happen, will happen,
   one bank                                and must not starve anybody
```

**One asker.** Give it everything. Trivial, and the important one.

**Six askers, disjoint.** Each face reading its own layers, in long sequential
bursts, from regions that do not overlap. Round-robin at a quantum large enough
not to chop a burst up and small enough that no face waits longer than `053`
tolerates.

**Six askers, one bank.** Should not happen if `038`'s interleaving distributes
the layer slices well, and will happen anyway. The policy must be starvation-free
and this blueprint must **prove** it rather than assert it: a face that is never
served stalls the whole pipeline behind it, and there is no operating system here
to notice.

## The other two clients

The **spout** wants two mebibytes at once and wants it rarely. It is a
**low-priority** client with a bounded worst-case wait, not a high-priority one:
a pane arriving a microsecond late costs nothing and a token arriving late costs
a pipeline bubble.

**Scrub** traffic from `040` runs continuously at a rate five orders of magnitude
below the core's bandwidth and must be entirely invisible. Lowest priority, no
exceptions.

## Symbols

```symbols
n_port        | 1   | derived | n_face + 2                        | clients on the switch: six faces, the spout and the scrubber
w_xbar_slice  | bit | given | 1024                                | width of one crossbar slice, the granularity the fabric is built in
n_xbar_slice  | 1   | derived | w_tier_port * n_tier / w_xbar_slice | slices needed to carry the whole core at once
q_arb         | bit | given | 65536                               | arbitration quantum: how much one client is given before the arbiter reconsiders
a_xbar_slice  | mm^2| measured | 0.021                            | area of one crossbar slice's worth of switch at this node, including its buffering
e_xbar_bit    | pJ/bit | measured | 0.045                         | energy to move one bit through the switch fabric

B_bisect      | bit/s | derived | n_xbar_slice * w_xbar_slice * f_core | bisection bandwidth of the fabric
A_xbar        | mm^2  | derived | n_xbar_slice * a_xbar_slice * n_port | area the switch occupies, which is what sets the cage thickness in 012
P_xbar        | W     | derived | e_xbar_bit * B_core                  | power it takes at full traffic
t_quantum     | s     | derived | q_arb / B_face_even                  | how long one client holds the switch before the arbiter reconsiders
t_wait_face   | s     | derived | t_quantum * (n_face - 1)             | worst case a face waits when all six are asking, which is what 053's stage budget must absorb
t_wait_spout  | s     | derived | t_quantum * n_port                   | worst case the spout waits, being low priority
t_wait_scrub  | s     | derived | t_quantum * n_port * 2               | and the scrubber, being lower
A_cage_avail  | mm^2  | derived | 6 * L_cavity^2 * t_cage / t_cage     | silicon area available in the cage shell, taken as its six inner faces
```

## Constraints

```constraints
C-037-1 | B_bisect >= B_core            | the fabric must carry everything the tiers can deliver, or the switch is the bottleneck rather than the memory and every performance number in 080 is wrong
C-037-2 | A_xbar < A_cage_avail         | the switch must fit in the cage. This is what sizes t_cage in 012, and if it fails the cavity shrinks and the core with it
C-037-3 | P_xbar ~= P_crossbar          | the power derived here must be the figure 020's budget assumed. Two routes, one number
C-037-4 | t_wait_face < t_stage / 100   | a face's worst-case wait must be a hundredth of a pipeline stage, so that arbitration never shows up in 080's model
C-037-5 | t_wait_scrub < t_scrub_period | even the lowest-priority client must finish. Starvation freedom expressed as a bound rather than as a promise, which is the only form of it that can be checked
C-037-6 | q_arb > w_tier_port           | the quantum must be larger than a single cycle's read, or the arbiter reconsiders faster than the memory answers
```

## What is still open

**Starvation freedom is bounded, not proved.** The constraints above give a
worst-case wait per client class under the stated policy. Nothing shows that the
policy is the one implemented, and nothing covers the case where a client's
request is refused rather than delayed — which `054` needs and neither blueprint
provides.

**The area figure is a `measured` with no source.** The cage's thickness in `012`
is set by `C-037-2`, so if the switch is twice the assumed area the cavity
shrinks by six millimetres and the core loses four tiers.

**Nothing arbitrates writes against reads.** The traffic is overwhelmingly reads,
and the writes that exist — staging buffers, the request region — are small and
latency-sensitive in a way a round-robin quantum sized for long bursts serves
badly. `053` has not asked for anything better and probably should.
