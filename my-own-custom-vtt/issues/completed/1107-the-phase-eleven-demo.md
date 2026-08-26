# 1107 -- The phase eleven demo

**Phase:** 11, the second view and the documentation
**Blocked by:** every other issue in phase 11.
**Blocks:** nothing. The capstone of the whole project.
**Documents:** [the roadmap](../../docs/015-roadmap.md)

## Current behaviour

**Done.** `./run-phase-demo 11`, in two halves.

**In process** (`105-demo-phase-11`): a generated inn, two people with different
scopes standing in different rooms, and the bytes each of them would receive --
decoded by reading them rather than by asking the filter what it would have sent.
The two streams differ in walls, things and appearances, and neither is a
filtered copy of a fuller one, because there is no fuller one anywhere.

Then what an appearance costs, measured. Then the first sprite on the wire
reassembled layer by layer, so the demo shows that what arrives really is a
sprite rather than a number claimed to be one.

**Out of process** (the wrapper): a real server generating the old inn, two real
terminal views joining as different people, and a real bridge serving a browser
at the same time. Both terminals print their last frame, side by side, and they
are different pictures of the same session.

Then the bridge is knocked on: `/` answers 200, `/engraving` answers 200, and
`/../etc/passwd` answers 404 -- a fixed table matched by exact path, so `..` is a
question the program cannot be asked.

Then the documentation site is built and its report printed, so it is read rather
than filed.

Then **every open question, by number**. Fifty-two of them, with a sentence
saying that a project reporting itself finished while holding these is reporting
the wrong thing.

Everything the wrapper starts is killed on the way out, whatever happens. A demo
that leaves a server running is a demo that fails the second time somebody runs
it.

## Intended behaviour

### What it shows

**One session watched from two views at once.** A server, a bridge with a
browser, and a terminal view, all looking at the same world, with the same walls
and the same things arriving through the same instructions.

**And the server unchanged.** State plainly that adding the second view required
no server change, and if it required one, say what and call it a phase 4 defect.

**The appearance on the wire.** Show the instructions that carry a sprite, and
the bytes they cost per beat, measured rather than estimated.

**Two people seeing different things.** Two viewers with different scopes, side by
side, each showing only what its own gates let through -- which is the security
property demonstrated from outside the process for the first time.

**The documentation site, built.** Run the tool, report what it made, and say
where to open it.

### It is the capstone of the project, not just of the phase

Say what the eleven phases add up to, and say what is still open -- honestly, by
number, in a list somebody can work through.

## Suggested implementation steps

1. Start a server, a bridge and two terminal views from one script.
2. Drive some motion so there is something to watch.
3. Print the byte counts.
4. Build the documentation site and say where it is.
5. Print the open questions that remain, by number.
6. Confirm `./run-phase-demo 11`.
