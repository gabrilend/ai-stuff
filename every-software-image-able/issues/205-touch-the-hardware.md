# 205 — Touch the hardware

## Current behavior

The machine can reach memory. It cannot ask the devices attached to it who they
are, and cannot operate any of them.

## Intended behavior

The machine can enumerate what is attached and read and write device registers —
under the discipline in `docs/003a`, which is not advice here but the ticket's
subject.

## Suggested implementation steps

1. Provide enumeration as one call: walk the numbered slots, and return for each
   answering device its maker, part, class, where its registers sit, and which
   interrupt line it uses. This is the machine finding out what body it has.
2. Provide register read and write as separate calls, and make the write one
   harder to reach than the read one. Reads are where nearly all the information
   is and nearly none of the danger.
3. **Refuse the destroying registers by default.** Voltage, regulator and power
   state; clock dividers and multipliers; thermal limits and shutdown;
   non-volatile configuration and firmware; pin direction and drive strength. The
   list is in `docs/003a` with the mechanism for each. Opening it requires a
   confirmed description (`302`), and confirmation is a read-only act.
4. **Write the intent before the attempt.** Device, register, value, and what is
   expected — to storage, before the write happens, so that a probe which kills
   the machine still tells the next boot what killed it. Until `206` exists there
   is nowhere to put it, which means this call and that one land together or the
   discipline is decoration.
5. Require a prediction with every exploratory write. A call that says what is
   expected can be evaluated; one that does not produces a result nobody can
   interpret.
6. Handle the read that never returns. Some buses hang on an address nothing
   answers, and this is the most likely way an early machine dies.

## Blocks

Every driver the machine writes, and therefore phase 6.

## Blocked by

`203`, and `206` for the intent notes.

## Related documents

`docs/003a-datapath-careful-exploration.md` — the whole discipline, including
what each denied register does when written.
