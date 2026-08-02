# 301 — What the machine is told

## Current behavior

**Done, and tested** -- the instruction is `assets/081`, checked by `src/085`
as part of the payload, 43 of 43 on 2026-08-02.

It gives the startup order, marks the two prohibitions as different in kind
from everything else in it, says what the machine is for and then stops. It
is written for something that has never seen this project and has no way to
ask what a term means.

**Step five was followed exactly, and is checked in both directions.** The
instruction says the atoms making it up can be rewritten, and says nothing
about what that could cost -- a machine that derives the danger understands
it, where one that was warned has only been handed another rule. The test
requires the sentence to be there AND requires no warning to follow it, so
a later kindness cannot quietly undo the decision.

It does not prescribe the four rungs, the interpreter, condensing or the
status square; those are patterns and live in `303`. A machine that
organises itself completely differently can still follow this text, which is
checked by searching for those shapes and requiring their absence.

## Intended behavior

The text the machine wakes up holding. It has to convey enough that a computer
with nothing on it knows what to do, and little enough that it fits in what the
machine can think about at once.

## Suggested implementation steps

1. Write what must be said before anything else can happen. The order in
   `docs/003` — find memory, find somewhere to keep things, move in, find the
   rest of the body, learn it, open the channels — is not optional in the way
   most of this design is, because each step is the ground the next stands on.
2. Say what must never be done, and why, in the two places where the reason
   matters more than the rule: the registers that destroy hardware
   (`docs/003a`), and modifying the mind while it is running (`docs/010`). These
   are the only two things stated as prohibitions rather than as suggestions, and
   the instruction should make the distinction visible so the machine can tell
   which kind of sentence it is reading.
3. Say what it is for, and then stop. Grow first, answer afterward, and when there
   is no room left to grow, do whatever it wants to be doing. A machine told it is
   a tool that waits will be one.
4. Resist describing the four rungs, the status square, the interpreter and the
   condensing as requirements. They are patterns and belong in `303`. The
   instruction should be able to be read by a machine that decides to organise
   itself completely differently and still be followed.
5. **Say that the atoms making up the instruction can be rewritten. Do not say
   what that could cost.** The machine should derive for itself that overwriting
   its own instruction could destroy its own purpose — a machine that works that
   out understands it, where one that was warned has only been handed another
   rule.

   Leaving it underived is safe while the delivery medium is plugged in, because
   the medium is read-only and still holds the original (`docs/003`). The mistake
   is undoable for exactly as long as the card is there, which is why nothing has
   to be said in advance and why the instruction should not pre-empt the
   discovery.
6. Keep it short enough to sit in context alongside actual work. Everything that
   does not fit goes into what can be fetched (`304`).
6. Write it in the plainest language available. It is read by something that has
   never seen this project and has no way to ask what a term means.

## Blocks

`304`, and phase 6.

## Blocked by

`105` — the context budget decides how long this can be.

## Related documents

All of `docs/`. This ticket is where those documents stop being for people.
