# 504 — Six askers, one store

Produces `src/037-core-six-port-arbitration.md`.

## Current behavior

Nothing. The cage is described as "a crossbar wide enough that one face can take
everything" and no arbitration has been specified.

## Intended behavior

**The switch between six radial links and thirty-two banked tiers, and the policy
that decides who gets what.**

### The requirement that shapes everything

**Any one face must be able to take the core's entire bandwidth when the others are
idle.**

This is not a performance nicety. During single-stream generation the sieve makes
exactly one face active at a time. If a face can only ever get a sixth of the
core, the six stages take six times as long as one stage would, and the sieve costs
a factor of six in latency — which is precisely the objection `008` entry 5 says
is wrong. **The objection is only wrong if the crossbar is built this way**, and
this ticket is where that is either delivered or the architecture's central claim
fails.

The cost is a full-bandwidth path from every port to every bank, which is a real
area and power cost in the cage, and the blueprint must show it rather than hide
it.

### The policy

Three cases, and they want different things:

**One asker.** Give it everything. Trivial and the important one.

**Six askers, disjoint regions.** The sieve's normal state: each face reading its
own layers' weights, in long sequential bursts, from regions that do not overlap.
The right policy is round-robin at a coarse granularity — large enough that a
burst is not chopped up, small enough that a face is never starved for longer than
`704`'s schedule tolerates.

**Six askers, one contended bank.** Should not happen if `505`'s address map
distributes the layer slices well, and will happen anyway. The policy must be
starvation-free and the blueprint must prove it, not assert it: a face that is
never served stalls the whole pipeline behind it, and there is no operating system
here to notice.

### The other two clients

The **spout** wants two mebibytes at once and wants it rarely. It should be a
low-priority client with a bounded worst-case wait, not a high-priority one, because
a pane arriving a microsecond late costs nothing and a token arriving late costs a
pipeline bubble.

**Scrub** traffic from `507` runs continuously at a low rate and must be entirely
invisible. Lowest priority, no exceptions.

## Symbols this must publish

Port count, bank count, crossbar bisection bandwidth, per-port maximum bandwidth,
arbitration granularity, round-robin quantum, worst-case wait per client class,
crossbar area and power, and the number of simultaneous full-rate ports supported.

## Constraints this must assert

- Per-port maximum bandwidth equals `501`'s aggregate. **The central constraint.**
- Bisection bandwidth is at least the aggregate, or the crossbar is the bottleneck
  rather than the memory.
- Worst-case wait for a face is under `704`'s tolerance.
- Starvation freedom, expressed as a bounded worst-case wait for every client
  class including the lowest.
- Crossbar power is within the cage's allocation in `301`.

## Suggested implementation steps

1. State the single-face-takes-all requirement first and derive the crossbar
   topology from it.
2. Work the area and power and put both in `301` rather than letting the cage's
   allocation be a guess.
3. Write the three-case policy with a bound for each.
4. Prove starvation freedom over the policy rather than asserting it.
5. Place the spout and scrub explicitly, with their priorities justified.

## Blocks

`505`, `506`, `701`, `704`, `901`.

## Blocked by

`501`, `503`.

## Related documents

`004` and `008` entry 5, both of which depend on this ticket being delivered as
specified.
