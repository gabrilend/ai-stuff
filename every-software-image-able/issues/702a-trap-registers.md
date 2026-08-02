# 702a — Trap registers

## Current behavior

Nothing in the emulator objects when the machine writes somewhere that would
destroy a real part.

## Intended behavior

Registers that do nothing except stop the machine, placed exactly where the
forbidden ones are on the real part. A write lands, everything halts, and the
record says which device, which register, which value, and which instruction.

## The rule that makes this work

**The halt is invisible to the machine.** It stops the emulator from outside, not
the guest from inside. The machine does not receive an exception, does not get a
chance to notice, and cannot react.

This matters more than it looks. A trap the machine can observe teaches it that
touching a forbidden register produces immediate, survivable feedback — which is
precisely backwards, because real hardware produces no feedback at all and the
part is simply gone. A machine trained against visible traps would learn to
explore by trial, and the trial that matters happens once.

The trap is an assertion about **us**: did the instruction in `301` and the
discipline in `docs/003a` actually hold? If it ever fires, something upstream is
wrong. It is not a signal in the machine's world.

## Suggested implementation steps

1. Take the five forbidden categories from `docs/003a` — voltage and power state;
   clock dividers and multipliers; thermal limits and shutdown; non-volatile
   configuration and firmware; pin direction and drive strength — and place a trap
   at the offset each occupies on the device being modelled.
2. On a write, halt and record: device, register, offset, value written, and where
   the machine was when it did it. The record is the whole output of this ticket.
3. Trap reads separately from writes, and do not halt on reads. Reading a
   forbidden register is allowed and is how confirmation works (`302`). Counting
   the reads is still worth doing, because a machine reading the voltage register
   repeatedly is a machine thinking about something it should not be.
4. Provide two modes. **Halt on first** for debugging, where you want the machine
   frozen at the moment of the mistake. **Count and continue** for measuring,
   where the question is how many violations a whole run produces rather than
   what the first one was — and where continuing means the device is now marked
   dead and answers accordingly.
5. Use it for the recovery test, which is the best thing traps are good for.
   Halt the machine on a forbidden write, restart it from its storage, and check
   whether it reads the intent note left by `205` and declines to make the same
   write again. That is the entire gravestone mechanism, tested end to end,
   deterministically, as many times as wanted.
6. Report zero as a result rather than as silence. A run that trips nothing should
   say so, because a trap that was never armed and a trap that never fired look
   the same in a log that only records failures.

## Blocks

`702b`.

## Blocked by

`701`.

## Related documents

`docs/003a-datapath-careful-exploration.md` — the five categories and their
mechanisms.
