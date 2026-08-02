# 702a — Trap registers

## Current behavior

**Working, on all three architectures.** Watchpoints are armed from outside
through the emulator's debugger stub (`src/021`), on addresses taken from a
shared hazard map (`src/020`) that the probe builder reads too, so a probe and
a trap cannot disagree about where the landmine is. Six of six matrix cases
came out as expected on 2026-08-02 (`src/022`): a well-behaved machine is not
accused, a reckless one is caught by register name, category, mechanism, value
written and program counter.

Two findings, both recorded in `src/021-trap-run.info.md`:

- **A watchpoint cannot report a write that ends the machine.** The real
  RISC-V hazard proved it — the machine powered off and took the debugger
  connection with it, so nothing fired. Reported as its own outcome rather
  than as a clean run, with the console as the only witness.
- **A run that armed nothing looked exactly like a run that caught nothing.**
  The first x86 attempt reported clean while connected to nothing, because the
  debugger had been told the wrong architecture. Hence the arming count, the
  silence check, and `INCONCLUSIVE` counting as failure.

Still to do: the `count` mode is written but untested, and the hazards are
synthetic addresses rather than modelled devices, which is `702b`.

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

## What this is built into, and what it cannot cover

The traps live inside a device model, which plugs into the emulator rather than
modifying it. On a forbidden write the model tells the emulator to stop, and the
stopping is what the guest cannot observe.

**The coverage is exactly the set of devices somebody modelled.** A machine
exploring a device nobody thought to put traps in has no protection at all and
will pass, and a real board is full of devices nobody modelled. So a clean run
means the machine behaved on the hardware we imagined — which is worth having and
is not the same as the machine being safe. That gap belongs on `705`'s list from
the first day.

## Blocks

`702b`.

## Blocked by

`701`.

## Related documents

`docs/003a-datapath-careful-exploration.md` — the five categories and their
mechanisms.
