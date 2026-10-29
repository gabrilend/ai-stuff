# Open questions

Every question that surfaced while designing. Each is waiting for the owner
until it has an answer written under it. A task touching one is in progress,
not finished, until it is answered.

## 1. What is crystallized?

The vision says that while waiting, the steward may use unused resources,
"never touching the ones that are crystallized". The design takes
crystallized to mean the monorepo clone plus anything listed in
`input/crystallized`. Is that the meaning? Or is crystallized something
else: work that has been approved, files that have stopped changing,
finished projects?

**Answered** (notes/vision, third part): the other side's parts. Neither
side touches what the absent side owns until it returns, or until the part
is no longer wanted ("forced cooperativity by tying together two ankles").
Written into `docs/datapath-link.md`, "Crystallized: the other side's
parts", and `docs/datapath-placement.md`, where every rule now names its
owning side.

## 2. Should the steward have any work it may land without the gate?

The design gates every change that reaches kuvalu. Some kinds might be safe
to let through: a new file in a project's `desire/` or `llm-transcripts/`, or
a new issue file. Should any kind be let through without approval, or
should every change wait for you?

## 3. Cloud session, or Claude Code on the Linode?

"Claude-cloud session" could mean Anthropic's hosted sessions, or Claude Code
running on the Linode. The design uses the second (`docs/roads-not-taken.md`
says why). Did you mean the hosted kind specifically?

## 4. The shared repository: kuvalu, GitHub, or both?

The monorepo already pushes to `github.com/gabrilend/ai-stuff`. The design
syncs kuvalu and the distant computer directly over the link, and leaves
GitHub to you. Should the distant computer also be able to push its
`distant-work` branch to GitHub, where you could read it from anywhere?

## 5. The budget

What is the API spending ceiling per month, and should the steward stop at
it, or ask for more with a `decision` request first?

## 6. "Possibly others"

The vision names `/home/ritz/programming/ai-stuff/` and "possibly others".
Which other folders, when the time comes?

## 7. Which projects first?

Should the steward work across every project with open issues, or start with
a short list you choose?

## 8. Where does a wish enter?

The vision's second part (notes/vision, after the second rule) describes the
whole system's purpose. Someone notices that a thing is overpriced, or wishes
a thing existed, and the system builds what makes it. Today the steward only
works from issue files the owner already wrote. Where would a wish like that
be written, who may write one (only the owner, or anyone), and what turns a
wish into a project with a vision?

## 9. What does "civic" mean here?

Candidate words, most likely first: owned by the people who use it (a
co-operative); run for public benefit rather than profit; anything made is
free for anyone to copy (a commons); answerable to a community, which votes.
Which, or something else?

**Answered** (notes/vision, third part): "civic is the noblesse oblige of
the common man - it's what we owe to each other." Not a legal form but a
duty: a venture's obligation to the people around it. How the duty becomes
something a program can check is question 11.

## 10. What is the test brigade?

"Anytime real decisions are to be made, about execution processes, the
questions are rallied through a test brigade." Readings, most likely first:
a set of voices that each argue a different side of the decision before it
reaches a person; a set of tests that each option must pass (cost,
safety, waste) before it is offered; real people who try the thing and
report back. Which one, or a mix?

## 11. How does "what we owe each other" show up in a decision?

If civic is a duty, something has to notice when a plan neglects it. Should
the test brigade carry a member whose only job is to ask "who does this
leave worse off, and what do we owe them?" for every decision?

## 12. Does the wish exist already?

The first wish, plastic wrap 1.5 times as wide, may already be sold:
food-service cling film comes in rolls 18 inches wide, which is 1.5 times the
usual 12-inch kitchen roll. Should the first thing the system does with any
wish be to search for what already exists and what it costs, and offer
that, before building anything?

## 13. The tools made from the same metal

The second wish has every drill bit and cutting tool made of the same
material as the outputs, so all waste can be melted and remade. A cutting
tool has to be harder than what it cuts. Tools of the same alloy can work
if they are hardened by heat treatment, and remelting undoes the hardening,
so the loop can still close. But the tools would wear faster than carbide
ones. Is "one material, many tempers" the meaning? Prior work worth
studying: RepRap (printers that print their own parts) and Open Source
Ecology's Global Village Construction Set (fifty open machines meant to
build one another).

## 14. Where does the wish-to-venture agent live?

The vision's aim (`docs/purpose.md`) is much larger than keeping two
computers in step. Should the agent that turns a wish into a venture be:
more phases of this project (10 onward), a new project that uses
distant-computer as its workshop, or the first thing the steward builds for
itself once phase 6 works?

## 15. What does a venture look like as files?

A software project here is a folder with a vision, docs and issues. A
venture also has members, roles, money and agreements with other ventures.
Should a venture be a project folder with more kinds of files (members/,
roles/, agreements/, ledger), so that the same tools read it?
