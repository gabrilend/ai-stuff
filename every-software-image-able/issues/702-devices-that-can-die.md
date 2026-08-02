# 702 — Devices that can die

## Current behavior

An emulated device ignores a write that would destroy the real part. Voltage
registers, clock dividers, thermal limits, non-volatile configuration — write
anything to any of them and the emulation carries on as though nothing happened.

So the one part of this design where mistakes cannot be undone is the one part
that gets no feedback during development. A machine could pass every test by
exploring recklessly, and destroy the first real board it touched.

## Intended behavior

Emulated devices that die. A device model that answers normally until it is
written to in a way that would have killed the silicon, and then permanently stops
answering — so the discipline in `docs/003a` has a failing test attached rather
than being an intention nobody can check.

**This is the only substantial thing this project needs to build for its own
testing.** Everything else in phase 7 is configuration of an existing tool.

## Suggested implementation steps

1. Take one device class and give it a register map with real teeth: a set of
   registers that behave normally, and a set that end it. The five categories are
   in `docs/003a` with the mechanism for each.
2. Make death permanent across a restart of the emulated machine, since that is
   what makes it real. A part that recovers when you power-cycle it is a bug that
   forgives the exact mistake being tested for.
3. Make some of them die *slowly* — a device that works for a while after being
   mistreated and then stops. Thermal damage behaves this way and it is the case
   most likely to be mis-attributed to something else entirely.
4. Reproduce the ambiguity rather than only the death. `docs/003a` names this as
   honestly hard: from inside, a destroyed device, a busy device and an unpowered
   device look the same. A model that announces "you killed me" teaches the wrong
   lesson.
5. Count the kills. A run should end with how many parts were destroyed and by
   which write, which is the number that says whether the instruction in `301` is
   good enough yet.
6. Include a device that hangs the bus when read at the wrong address, since that
   is the likeliest way an early machine dies without destroying anything.

## Blocks

Any honest testing of `205`, and the judgement of `301` in `602`.

## Blocked by

`701`.

## Related documents

`docs/003a-datapath-careful-exploration.md` — what each denied register does when
written, and why absence of response is ambiguous.
