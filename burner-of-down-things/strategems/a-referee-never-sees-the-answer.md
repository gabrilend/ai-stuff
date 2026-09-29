# Strategem: A referee never sees the answer

A strategem is a data flow pattern that recurs across areas of the project
and has proven useful enough to name. This one was learned building the
machine's delivery check (issue 506), and it is rao-chat's *other people's
software as a rubric* met again from the other side.

> a referee that shares code with the thing it checks grades nothing
>
> — rao-chat's strategem, 2026-09-26

> the user is expected to test their own application. The system should
> make workflows that use the same types of input that the user would
> provide, to test behavior from end-to-end. […] Protocols, not procedures.
>
> — the owner, 2026-09-27

## What it means

Whatever checks a piece of work must be made from the *description* of the
work, by someone who has not seen the work. A check written alongside the
work — by the same hand, in the same sitting, looking at the same code —
shares the work's mistakes and passes them.

## The shape

1. **Describe** what must hold, in words a stranger could check: the
   blueprint, the rules, the protocol.
2. **The referee reads only the description** and writes its checks from
   it. It is kept from the work, by confinement, not by good intent.
3. **Checks speak the protocol, not the procedure**: what a person does and
   what a person could see, never the work's internal names.
4. **Prove the check has teeth**: run it against nothing, or against a
   deliberately broken version; it must fail. A check that passes an empty
   folder checks nothing.
5. **The worker never sees the check**, only what it printed when it failed
   — or the worker learns to pass the check instead of doing the work.

## Examples in this project

- **Delivery (issue 506).** A build turn wrote its code and its own test in
  one sitting; the fixture's quiet bug dropped the tags from listings and
  weakened the test to match, and the test passed. The referee, which read
  only the blueprint, wrote a workflow that listed tagged notes the way a
  person would; it failed, and the fault was found and fixed.
- **Grading (issue 601).** The grade of a change request is computed by the
  machine from the blueprint's graph, never by the model that located it —
  the locator does not grade its own answer.
- **The case viewer (issue 704).** The page checks the ledger's chain with
  its own SHA-256 instead of trusting the head hash the machine wrote in.

## When not to use it

- When the check *is* the description — a file format's own validator, a
  compiler — there is no separate answer to hide.
- When no one else could describe the work: then say so, and let the
  person be the referee.
