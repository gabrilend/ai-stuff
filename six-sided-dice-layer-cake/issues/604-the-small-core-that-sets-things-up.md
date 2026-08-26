# 604 — The small core that sets things up

Produces `src/044-scalar-core.md`.

## Current behavior

Nothing. A scalar core has been mentioned and never described.

## Intended behavior

**The pipeline, the register file, and the memory interface of the smallest
processor that can do this job**, plus an argument for why it is that small.

### What it actually does

Per token, per face, the scalar core builds descriptor chains for thirteen layers
and hands them to the sequencer. That is a few hundred instructions of pointer
arithmetic against a hundred and fifty microseconds of tensor work. **The core is
idle over ninety-nine per cent of the time**, and on face five it additionally runs
the sampler, which is the only genuinely data-dependent work in the machine.

An eight square millimetre in-order scalar core is therefore not a compromise, it
is generous. The blueprint should present the utilisation figure early, because it
is the justification for everything else being small.

### The design

In-order, short pipeline, no speculation, no out-of-order machinery, no branch
predictor beyond a static hint. Every one of those omissions is area returned to
the slice in `607`, and none of them costs anything measurable when the core is
idle ninety-nine per cent of the time.

The parts that do need care:

**The memory interface.** The core reads and writes the core memory across the
radial link like everything else, and a link round trip is long. A core that
stalls on every descriptor field read would spend its whole budget waiting. It
needs a small local memory for descriptor construction and enough outstanding
requests to hide the link, and the blueprint must say how many from `703`'s
latency.

**The barriers.** `506`'s release and acquire are scalar instructions and their
latency directly costs pipeline stage time in `704`. They are the only scalar
instructions on the critical path and deserve their own timing budget.

**The sampler's random state.** It must be carried, reproducible, and per-sequence,
because two runs of the same prompt with the same seed must produce the same text
or nothing in `1205` can be tested. Where that state lives and how it advances is
a real specification and not an implementation detail.

### Four cores or one

`602` leaves open whether each of a face's four dies has its own scalar core. Four
idle cores cost thirty-two square millimetres of area to avoid inter-die traffic
for descriptor construction. One core costs that traffic. **Four, almost
certainly** — the area is one and a half per cent of a face and the alternative
puts a link round trip inside the setup path — but the blueprint must do the
arithmetic rather than assert it.

## Symbols this must publish

Pipeline depth. Register file size and width. Local memory size. Outstanding
request count. Barrier latency. Instructions executed per token. Utilisation.
Area and power. Random state width and advance rule.

## Constraints this must assert

- Instructions per token times the cycle time is under a stated fraction of a
  layer time, which is the utilisation claim as arithmetic.
- Outstanding request count times the transfer size covers the link latency from
  `703`, or the core stalls.
- Barrier latency is inside `704`'s per-stage allowance.
- Area and power are within the allocations in `601`.

## Suggested implementation steps

1. Count the instructions a token actually needs and derive the utilisation.
2. Design the pipeline to that, not to a benchmark.
3. Size the local memory and the outstanding requests from `703`'s latency.
4. Give the barriers their own timing budget.
5. Specify the random state and its advance rule.
6. Do the four-versus-one arithmetic.

## Blocks

`608`, `1205`.

## Blocked by

`601`, `602`, `603`, `703`.

## Related documents

`003` for the sampler's place in a pass.
