# 005 — Open questions

Every decision this project has had to make that the vision does not make for
it. The ones the vision asks out loud — voting, seniority, expertise, being made
to work differently, externalities, hidden complexity, people who stop
working — are ruled on in [acceptance](003-how-a-change-is-accepted.md#the-questions-the-vision-asks-ruled-on).
What is below is what is left: each with a **working ruling** the tools are
built on, why it matters, and what would change if it were answered otherwise.

Entries are kept when answered, rewritten to say the answer and what was
rejected. Nothing is deleted.

---

## Q1 — What soramech is

**Working ruling:** the reading in [what this is](001-what-this-is.md#what-soramech-is-as-this-project-reads-it),
taken from `soren-ds/docs/012-soramech-runtime.md` because the parent project
named in the vision, `minimal-soramech`, is not in this repository.

**Why it matters:** the map format copies soramech's rules — first word a
keyword, wires at both ends, fixed values, doors, readiness read off ports. If
the parent differs, the format should follow it while there are few maps to
migrate.

## Q2 — What the interface looks like

The vision points at `ceramic-trainstation` for the visuals, also not in this
repository, and says the interface matters less than the model.

**Working ruling:** every view is generated from the files and is plain HTML
with no JavaScript, or plain text. A view never holds state the files do not.
When the trainstation prototype is available, its picture becomes one more
reader of `org.map`.

## Q3 — Money

Does holding a box pay? Who decides pay?

**Working ruling:** money is not special. A payroll is a role, pay is a wire
from it to the boxes it pays, and changing pay is a wiring change that needs
both ends. That makes pay as visible as everything else, which an org may or
may not want — and that is a question for a person, not a format.

**Why it matters:** this is where a real organisation would first collide with
the model, and the first place somebody would want a rule that names a person.

## Q4 — Who attests that a port is fed, and disputes

**Working ruling:** the holder of the waiting box writes the `fed` line,
because the one who is blocked is the one who knows. A producer who thinks they
delivered and a consumer who says they did not is a conversation, not a rule;
the repository's history records who wrote which line.

## Q5 — Old state

A `fed` line from months ago may no longer be true.

**Working ruling:** every state line carries a date, and nothing expires. A
later board may age them. Expiry would be a rule about time that nobody chose.

## Q6 — Scale

`approve everyone 2/3` for a rules change works for a bakery and not for five
thousand people.

**Working ruling:** a large org is a map of maps (`inside`), and each inner map
has its own rules. How the outer map's rules bind the inner ones is open; until
it is answered, **a proposal edits exactly one map**, and a change that spans
two is two proposals.

What is settled (issue 201) is the wall between them: an inner map reaches the
world only through its box's ports (N5), so a change inside cannot open a door
the outer map's rules never see. Changing what the box exchanges is a change to
the outer map, under the outer rules; how the box does it is the inner map's.

## Q7 — Anonymous objections

**Working ruling:** none. An objection names its author and its reason, so it
can be answered. If fear of retaliation makes people stay quiet, that is a real
cost, and the answer may be an anonymous objection that does not block but is
recorded — not decided.

## Q8 — Proposals that sit forever

**Working ruling:** nothing expires. A proposal is stale when the map moves
under it, withdrawn when its author says so, and otherwise waits. Silence never
turns into consent (see acceptance), and so silence does not turn into refusal
either.

## Q9 — Removing somebody against their will

**Working ruling:** the map cannot do it. Removing a `person` affects only that
person; anybody may route around anybody by moving their own wires. What an
organisation does about somebody everyone has routed around — stops paying
them, asks them to leave — happens outside the map, and the map shows it
happened.

## Q10 — State across a box's wall

The outer `org.state` says whether the box's `in spec` is fed; the inner one
says whether `cutting.spec`, the door that port leads to, is fed. Nothing yet
makes the two agree.

**Working ruling:** each map's state is its own, written by the people waiting
in that map, as everywhere else. The board looks inside a source using the
inner state. Deriving one from the other — an inner door in fed whenever the
box's port is — would be tidier and would mean a state line in one directory
changes the meaning of another's; that is worth deciding with a real nested
org in front of us rather than in advance.
