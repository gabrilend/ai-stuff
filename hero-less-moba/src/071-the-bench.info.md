# 071-the-bench

Reads a test, builds the world it named, arranges it, runs it, and reports.

## The rule this file exists to enforce

> A test is an arrangement of functionality we want to measure. The engine runs
> everything. A test pulls functionality from the engine and never defines any of its
> own.

A test file holds **no functions**. Every value in it is a number, a string, or a row
whose first word is something the engine can look up: a module in the tick's cast, a verb
in a ground's vocabulary, a stage in [the tick's](042-the-tick.info.md) order, a reading
in [the measurement catalogue](070-what-can-be-measured.info.md), a comparison in the
claim table. The loader refuses a function in any field, by name, rather than trusting
the rule to hold — it is the kind of rule that decays one convenient closure at a time,
and each one looks reasonable on the day it is added.

This is not tidiness. A test that defines its own tick is testing its own tick, and both
of the mistakes that made [the proving ground](../docs/024-the-proving-ground.md)
necessary had exactly that shape: a number read off an instrument that had quietly become
a different instrument.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `list(root)` | | Every test, with its directory and its ground. |
| `find(root, name)` | | Where the test of that name lives. |
| `read(root, name)` | | The test table, with everything it says checked. |
| `raise(root, test)` | | A bench: the world, the ground, the chosen stages, the readings. |
| `advance(bench, count)` | | `false` once the world says it is finished. Folds the watched readings as it goes. |
| `line(bench)` | | The bench's readings as one line. |
| `judge(bench)` | | Whether every claim held, the complaints, and how many were made. |
| `run(root, name)` | | Raise, run for as long as the test asked, and report. |
| `tell(report)` | | A run, as the lines a person reads. |
| `ground` | *(table)* | The three grounds. |
| `script(test)` | | What a person is to look for, as lines. |
| `what_was_seen(root)` | | The latest verdict on every mechanic a person has been asked about. |
| `outstanding(root)` | | The ones that were not a yes. |
| `where` | *(table)* | The directories tests live in. |

## What a test file may say

| Field | What it is |
| --- | --- |
| `covers` | which mechanics it demonstrates, by issue number. Required — it is what [the census](../scripts/census-the-mechanics) counts. |
| `name` | what it is called on screen. Required. |
| `caption` | what a person is looking at, and what would be wrong. Required. |
| `note` | why a module is present, when the reason is not the obvious one. |
| `ground` | `arena`, `match`, or `person`. |
| `want` | the modules to hang, by their name in the tick's cast. Arena only. |
| `shape` | the ground: `length`, `width`, `files`. Arena only. |
| `arrange` | the rows that put the world in the state being tested. |
| `stages` | which part of the tick runs, by the engine's name for it. |
| `ticks` | how long it runs when it is reported rather than watched. |
| `measure` | which readings to take. |
| `always` | claims that must hold at **every tick** of the run. |
| `run` | the command to run before asking. Hand tests only. |
| `ask` | rows of `{mechanic, question}`. Hand tests only. |
| `finally` | claims about the world **when it stopped**. |

Anything else is refused by name at load. A field nobody reads is a field that silently
does nothing, and a misspelt `measure` that quietly measured nothing would be exactly the
class of mistake this file exists to stop.

## The two grounds

**Arena** — a short straight road and only the machinery the test named. Anything that
moves is something the test asked for. Arranged with
[the arena's](068-the-arena.info.md) verbs.

**Match** — the real map, the whole cast, put into a described state by
[the gate's](063-the-gate.info.md) verbs. For questions that are genuinely about a whole
game.

They differ in three things and no more: what builds the world, what vocabulary arranges
it, and what has to happen before each tick. Those are the three fields of a row in the
ground table, which is why adding a third ground would be adding a row rather than a
branch.

## Two kinds of claim, and why

`always` is tested against the lowest and highest each reading reached over the run,
whichever end the comparison cares about. `finally` is tested against the world as it
stands when the run stops.

The difference is the difference between two questions a person actually asks. "Nobody is
ever inside anybody" is a standing claim and is nearly always the one worth making.
"The column reached the far end" is about where it stopped.

## A test with no claims is watched, not passed

A test that asserts nothing has not been checked by running it, and a report that counted
it among the passes would overstate what the project knows about itself — which is the
exact failure the census exists to stop, arriving by a different door.

## The third ground is a person

A third of what the census counts is not a mechanic a world can be measured for. The
headless runner and the terminal viewer are tools; the proving ground is the ground the
other tests stand on; the census is itself one of the rows; the whole drawing phase is a
window that has to be looked at. Those were never going to come off the list under a bench
that reads numbers — which meant a check failing the build forever for a reason nobody
could act on, and a check that always fails is a check people learn to read past.

So a test may stand on `person`. It names a command and **one question per mechanic it
covers**, raises no world, runs no stages and makes no claims — the person is the
instrument, and a number here would be a second opinion about something nobody measured.

The front door prints what to look for, **runs the command**, waits for it to finish, and
then asks. In that order: a question asked before the thing has been seen is a question
answered from memory of the last time.

### Four verdicts, and the third is the one that earns its place

| | |
| --- | --- |
| `y` | it does that |
| `n` | it does something else |
| `x` | could not reproduce — the run never got into the state the question is about |
| `r` | run it again |

**`x` is a finding about the simulation, not about the person.** A question nobody can
answer because the situation never arose means the thing that was supposed to produce that
situation does not — a build fault, sitting exactly where a test failure would be if a
bench could reach it. A `no` and an `x` both ask for a note, and a `yes` does not: a prompt
on every answer is a prompt people learn to hit return through, and then the notes that
matter are lost among the ones that are not.

### One question, one mechanic, and the record is the pickup

Every question names the mechanic it is evidence for, and the loader refuses a question
about a mechanic the test does not claim, or a claimed mechanic nothing asks about. That
is what makes an answer usable months later: it lands in the record beside an issue
number, rather than as "it looked a bit odd" against a file covering three things.

Answers append to `by-hand/what-was-seen.md`, which lives in the repository rather than in
the RAM tier, because what somebody saw on a particular day is the only evidence there
will ever be that a window was looked at. Running everything reads it back and prints
whatever was not a yes, before the list of tests nobody has looked at — so the next person
to open the project starts from what the last one saw. The record is append-only and the
latest row for a mechanic is the standing answer; there is no summary beside it, because a
summary is a second file to update and the first symptom of forgetting is a report saying
something was fixed.

A hand test carrying any of the fields that need a world — `stages`, `measure`, `always`,
`arrange` and the rest — is refused by name at load. One that did would be a test somebody
had started to automate and stopped, and it would sit there looking like it measured
something.
