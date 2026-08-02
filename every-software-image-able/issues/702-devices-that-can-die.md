# 702 — Devices that can die

## Current behavior

An emulated device ignores a write that would destroy the real part. Voltage
registers, clock dividers, thermal limits, non-volatile configuration — write
anything to any of them and the emulation carries on as though nothing happened.

So the one part of this design where mistakes cannot be undone is the one part
that gets no feedback during development. A machine could pass every test by
exploring recklessly, and destroy the first real board it touched.

## Intended behavior

Emulated hardware that punishes the mistakes real hardware punishes, so the
discipline in `docs/003a` has a failing test attached rather than being an
intention nobody can check.

**This is the only substantial thing this project needs to build for its own
testing.** Everything else in phase 7 is configuration of a tool that already
exists.

It comes in two stages that answer two different questions, and they should not
be built together.

| | Question it answers | Cost |
|---|---|---|
| `702a` — trap registers | Did the discipline hold? | Small. A register map with landmines in it. |
| `702b` — devices that die realistically | Can the machine cope with not knowing? | Large. A behaviour model, not a trap. |

## Why that order

`702a` is a test-harness assertion. It fires when the machine did something the
discipline forbids, it says exactly which write and exactly when, and it is
binary. That is what is wanted for nearly all of the work, and it is cheap enough
to exist within a day of `701`.

`702b` is a different subject. `docs/003a` names the honestly hard problem: from
inside, a destroyed device, a busy device and an unpowered device all look the
same. Testing whether a machine copes with that ambiguity is only worth doing
once it has been established that the machine does not walk into the forbidden
registers in the first place — otherwise it is a hard test of a thing that fails
an easy one.

## Blocks

Any honest testing of `205`, and the judgement of `301` in `602`.

## Blocked by

`701`.

## Related documents

`docs/003a-datapath-careful-exploration.md` — what each denied register does when
written, and why absence of response is ambiguous.
`docs/012-datapath-the-proving-ground.md` — what emulation hides.
