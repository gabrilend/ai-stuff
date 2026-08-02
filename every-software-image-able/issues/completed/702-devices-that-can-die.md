# 702 — Devices that can die

## Current behavior

**Done, and tested** -- `src/092` is the bench, `src/093` checks it, 18 of 18
on 2026-08-02. Its sub-issues `702a` (trap registers) and `702b` (devices that
die realistically) are both complete.

This was named the risk of the phase, and a risk of omission rather than of
difficulty: emulated devices ignore the writes that destroy real ones, so
without this the exploration discipline was an intention with no failing test
attached -- and a machine could pass every trap while exploring recklessly
somewhere nobody wrote a trap for, then kill the first real board it met.

It is now testable in both directions, which is the thing that was missing. A
machine following the discipline never reaches the fatal register and the
part survives; one that opens the register and is wrong about what it does
kills the part permanently -- and the note it was made to write first is
still there afterwards to be read, which is the whole reason that rule
exists.

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
