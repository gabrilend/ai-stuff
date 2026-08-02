# 205 — Touch the hardware

## Current behavior

**Done, and tested with `206`** — `src/077` is the hands and the discipline,
`src/078` checks both, 28 of 28 on 2026-08-02.

Enumeration is one hand: what answered, who made it, what it is, where its
controls sit, which line it pulls. Reading and writing are separate hands
and the writing one is harder to reach — it is marked dangerous, so it is
refused until opened, and reads are where nearly all the information is
anyway.

Three rules, enforced rather than recommended:

- **The note comes first.** Device, register, value and expectation go to
  storage *before* the write happens, because a probe that kills the machine
  cannot report anything afterwards — the reporting channel dies with the
  machine (`notes/023`). A machine with nowhere to write a note may not
  explore at all, which is the whole reason these two tickets land together.
- **A prediction is required.** A write that says what it expects can be
  evaluated; one that does not produces a result nobody can interpret.
- **The five destroying kinds are refused by default** — voltage, clock,
  thermal, non-volatile, pin direction — and each refusal says what that
  register does when written wrongly, because a refusal that does not
  explain itself teaches nothing and gets worked around. Confirming a
  description opens one kind and only that kind, and confirming is
  read-only.

A write reads the register back and returns what is actually there rather
than what was predicted. The difference between those two is the entire
content of an experiment.

Not covered, and named rather than forgotten: **a read that never returns**
— some buses hang on an address nothing answers on, and that is the most
likely way an early machine dies; nothing here prevents it. And **finding
the reset first**, which the discipline asks for and which a pretend device
has none of to find.

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
