# 301 — What the machine is told

## Current behavior

**Done, and tested** -- the instruction is `assets/081`, checked by `src/085`
as part of the payload, 43 of 43 on 2026-08-02.

It gives the startup order, marks the prohibition as different in kind from
everything else in it, says what the machine is for and then stops. It is
written for something that has never seen this project and has no way to ask
what a term means.

**Rewritten 2026-08-21, and it is a different document in four places.** There
were two prohibitions and there is now one. The second — never write into your
own weights — is gone, because the only things worth restricting are the ones
that damage hardware, and a machine that wants to do something stupid to itself
is allowed to. What was a rule on the card is advice it can go and fetch.

What arrived in its place: **what to do when stuck** (ask a person, or leave a
note saying HELP I'M STUCK, or blink S.O.S., or demolish what you were building
and start again); **whose the disks and the networks are** (no board is
expendable, write only where the bytes are already zero, assume you may touch any
network you are plugged into, mistakes matter but do not beat yourself up);
**build what suits this machine**, as a lean rather than a rule; and the fact
that **nothing will ever ask it anything**, because the mind is closed
(`docs/010a`) and a way of talking to a person is software it has to build.

It is 7998 bytes, which is under the ceiling the test enforces and close enough
to it that the next addition has to displace something. Every byte of it sits
outside the manageable context budget, so the instruction growing is the working
budget shrinking in the one region nobody measures (`docs/013`).

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

## The assumption this text rests on, written down 2026-08-04

**The machine supplies the instruction set from its own knowledge. Nothing in
the seed carries one.**

There is no opcode table on the chip, no mnemonic list, no encoding
reference. The patterns give shapes — *an interpreter is a loop that fetches
a number and looks it up in a table*. The descriptions give devices. This
text gives the order that cannot be rearranged. What none of them give is
what `mov` or `ldr` or `jalr` mean, or how many bytes any of them occupies.

That the model already knows is assumed, and it is a reasonable assumption:
anything able to write assembly at all knows this, and carrying an encoding
reference for three architectures would be larger than the instruction, the
patterns and the descriptions together.

It is written down here because it is **the load-bearing premise of the whole
bootstrap** and was nowhere. Everything the machine ever builds is downstream
of it writing correct assembly on the first try, with an assembler that will
encode what it is given and a processor that will run whatever that encodes
to. If the assumption is wrong, nothing else in the seed matters — and the
failure mode is the silent one, because assembly that assembles and does the
wrong thing does not announce itself.

It is not a thing to fix. It is a thing to know, and the place it gets tested
is `602`, by leaving machines alone and counting how many succeed.

## Intended behavior

The text the machine wakes up holding. It has to convey enough that a computer
with nothing on it knows what to do, and little enough that it fits in what the
machine can think about at once.

## Suggested implementation steps

1. Write what must be said before anything else can happen. The order in
   `docs/003` — find memory, find somewhere to keep things, move in, find the
   rest of the body, learn it, open the channels — is not optional in the way
   most of this design is, because each step is the ground the next stands on.
2. Say what must never be done, and why, in the **one** place where the reason
   matters more than the rule: the registers that destroy hardware (`docs/003a`).
   That is the only thing stated as a prohibition rather than as a suggestion, and
   the instruction should make the distinction visible so the machine can tell
   which kind of sentence it is reading.

   **It used to be two.** Modifying the mind while it is running was the second,
   and on 2026-08-21 it stopped being a rule and became advice the machine can
   fetch if it wants it. The reason is that a prohibition is only worth writing for
   something that damages hardware; everything else the machine is entitled to do
   badly to itself.

   And the surviving one ends differently than it used to. Confirm a description of
   the exact part if you can — and when you cannot, and cannot work around it,
   **ask a person**, explaining what worries you, why you want it, and how it would
   be done.
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
   does not fit goes into what can be fetched (`304`). The ceiling is enforced by
   the test at eight thousand bytes, and the text is within twenty of it — so the
   next thing added has to displace something, which is the correct pressure.
7. Say what to do when stuck, because a machine that needs a dangerous write and
   cannot reach anybody has to do *something*: leave a note saying HELP I'M STUCK,
   blink S.O.S. on whatever output exists, or demolish what it was building and
   start again aiming to miss the pitfall.
8. Say whose the disks and the networks are. No board is expendable; assume there
   is data on every disk and write only where the bytes are already zero; assume
   any connected network may be touched; mistakes matter, minimise them, and do
   not beat yourself up over them.
9. Say that nothing will ever ask it anything. The mind is closed (`docs/010a`),
   and a way of talking to a person is software the machine has to build and then
   work out how to advertise.
6. Write it in the plainest language available. It is read by something that has
   never seen this project and has no way to ask what a term means.

## Blocks

`304`, and phase 6.

## Blocked by

`105` — the context budget decides how long this can be.

## Related documents

All of `docs/`. This ticket is where those documents stop being for people.
