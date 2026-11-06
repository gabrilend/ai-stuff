# 003 — How a change is accepted

A **proposal** is the org's pull request: a file that says which lines of
`org.map` to remove and which to add, and below that, the answers people have
given it. Everything about whether it may be applied — what kind of change it
is, who it affects, whether enough of them have agreed — is **derived from the
lines**, never declared by the person proposing. A proposal cannot be labelled
"just a wording fix" if it moves a wire, because its own lines say it moves a
wire.

The vision asks the hard questions directly — "is it voted on, is there
seniority, do we trust expertise ... what if that's my thing and you're making
me do it differently" — and they are answered at the end of this page, each as
a ruling with its reason. The mechanism comes first, because the rulings are
only worth anything if they can be computed.

## A proposal file

`proposals/NAME.proposal`, in the [shared grammar](002-the-org-map.md#the-grammar-every-file-shares).

```
proposal oven-money-from-takings
  by ana
  opened 2026-11-01
  says "the books have not released the oven budget in a month"

edit work new-oven
  - in budget - books.oven-budget
  + in budget - selling.oven-money

edit role books
  - out oven-budget - new-oven.budget

edit role selling
  + out oven-money - new-oven.budget

object dee 2026-11-02 "the takings pay the mill first; this skips that"
approve bo 2026-11-03 513f1bd9
```

| Head | Body | Means |
| --- | --- | --- |
| `proposal NAME` | `by PERSON`, `opened DATE`, `says "WHY"` | Who proposes it, when, and why. |
| `add KIND NAME` | `+ LINE` … | A new block in the map. |
| `edit KIND NAME` | `- LINE`, `+ LINE` … | Lines removed from and added to an existing block. |
| `remove KIND NAME` | `- LINE` … | A block taken out of the map, every body line listed. |
| `approve PERSON DATE [CHANGE-ID]` | — | PERSON agrees. |
| `object PERSON DATE "REASON"` | — | PERSON does not agree, and says why. |
| `withdrawn DATE` | — | The proposer has taken it back. |
| `applied DATE [N]` | — | It has been applied to the map, as the org's Nth change. |

LINE is a body line of the map exactly as it would be written there, without
its two leading spaces: everything after the `+` or `-` and the spaces that
follow it, compared character for character. KIND is a map head keyword: `person`, `outside`,
`role`, `work`, `rule`, or `org` (which can only be edited).

| Code | Rule |
| --- | --- |
| P1 | The first head is `proposal NAME`, and NAME is the file's name without `.proposal`. |
| P2 | Exactly one `by`, naming a person in the map **or a person this proposal adds** — which is how somebody asks to join. Exactly one `opened`. At most one `says`. |
| P3 | A proposal's heads are `proposal`, `add`/`edit`/`remove KIND NAME`, and the answer lines. `add` blocks hold `+` lines only, `remove` blocks `-` lines only, `edit` blocks either, and at least one. Each body line is `+ LINE` or `- LINE`, and each LINE is well-formed for its KIND. `org` may only be edited. |
| P4 | A block is the target of at most one `add`/`edit`/`remove` in a proposal. |
| P5 | Answer lines are exactly the four shapes in the table above and have no body lines. `object` carries a non-empty reason: **an objection without a reason is noise**; with one, it is a record anybody can read and answer. An answer from somebody who is not a person in the org is not a problem — anybody can append a line — and does not count. |
| P6 | Not both `withdrawn` and `applied`; neither twice. N, when given, is a whole number from 1. |

**Answers are appended, not edited.** A person's answer is their latest line;
between two lines of one date, the later in the file. Changing your mind is
another line. The proposer's own `by` counts as their approval on the opened
date, unless a later line of theirs says otherwise.

**The change id.** An approval may end with a change id: eight lowercase hex
digits, the 32-bit FNV-1a hash (offset basis 2166136261, prime 16777619) of the
proposal's change — every `add`/`edit`/`remove` head and its `+`/`-` lines,
exactly as written including the two leading spaces, joined with `\n` with no
`\n` after the last, in file order. **An approval whose id does not match the change as it stands now does not count.**
That closes the hole a pull request has when the branch changes after it was
approved: you approved *that* change, not whatever the file says today. The id
is optional, because a format that cannot be used without a tool is not one
people can design their own tools for; an approval without one is taken on
trust and the proposal tool says so.

## Applying a proposal to the map

Precisely, so that two tools produce the same file:

1. **Check every `-` line against the map as it is.** In an `edit`, each `-`
   line must equal one body line of the target block. In a `remove`, the `-`
   lines must be exactly the block's body lines, each once. An `add` names a
   block that does not exist (in the shared namespace, M4); `edit` and
   `remove` name one that does. Any failure makes the proposal **stale**: the
   map moved under it, as a branch does, and the proposer rebases by
   rewriting the lines.
2. **Remove.** Each `-` line of an `edit` is deleted. A `remove` deletes the
   head, its body lines, the comments and blank lines between them, and any
   comment lines directly above the head with no blank line between — they
   were that block's comments.
3. **Add.** An `edit`'s `+` lines go directly after the last body line the
   block still has (after the head, if it has none left), in proposal order. An `add` appends a
   blank line and the new block at the end of the file, in proposal order. A
   `+` line identical to one the block still has makes the proposal stale.
4. **Tidy, only where something was removed.** A blank line that would follow
   a removal and sit directly after another blank line, or first in the file,
   goes; a removal at the very end of the file takes the blank lines before it
   too. Nothing the proposal did not touch is reformatted, so the diff holds
   only the change.
5. **Validate the result** against every rule in [the org map](002-the-org-map.md).
   A proposal whose result is invalid is **broken** — the commonest way is
   changing one end of a wire and not the other (M12).
6. **Carry the state across.** A `fed` line survives only if its port still
   exists with the identical `in` line — **a port that was rewired is waiting
   again**, because what fed it came from the old source. A `done` line
   survives only if its work box does.

## Status, derived

Checked in this order; the first that applies is the status.

| Status | When |
| --- | --- |
| withdrawn | it has a `withdrawn` line |
| applied | it has an `applied` line |
| invalid | it breaks P1–P6 |
| stale | step 1 above fails |
| broken | step 5 above fails |
| waiting | some rule below is not met; the tool names which |
| ready | every rule is met; it may be applied |

Nothing stores "accepted". A proposal is ready because its lines and its
answers make it so, and anybody can check that without trusting whoever says
it is.

## Kinds of change

Every changed line has a kind:

| Block | Line | Kind |
| --- | --- | --- |
| `org` | any | rules |
| `rule` | the block itself, or any line | rules |
| `person` | the block itself | people |
| `person` | `says` | inside |
| `outside` | the block itself, or any line | doors |
| `role`, `work` | the block itself | boxes |
| `role`, `work` | `says`, `in PORT = …`, `inside` | inside |
| `role`, `work` | `held-by` | holding |
| `role`, `work` | `in PORT - …`, `out PORT - …` | wiring |
| `role`, `work` | `in PORT $…`, `out PORT $…` | doors |

A proposal's kinds are the set of its lines' kinds, and **it must satisfy the
rule for every kind it has**. A proposal that adds a box, puts somebody in it
and wires it up is a boxes, holding and wiring change at once, and each rule is
checked with the people that kind of line affects.

## Who a change affects

For each changed line, on box A (holders before the change unless stated):

| Line | Added: affects | Removed: affects |
| --- | --- | --- |
| `says`, `in PORT = …`, `inside` on A | A's holders | A's holders |
| `held-by P` on A | P, and A's holders | P only |
| `in PORT - B.Q` on A — A is the consumer | A's holders | A's holders |
| `out PORT - B.Q` on A — A is the producer | A's holders | **B's holders** |
| `in`/`out` door to outside O on A | A's holders and O's speakers | A's holders and O's speakers |
| `person P` block, or its `says` | P | P |
| `outside O` block or any line of it | O's speakers, before and after | O's speakers, before and after |
| `role`/`work` block itself | nobody beyond its own lines | nobody beyond its own lines |
| `org` or `rule`, any line | every person | every person |

"A's holders" for a box the proposal adds are the holders it is added with.
Because every wire is written at both ends (M12), every wire change touches two
boxes — and the table is built so that **adding a wire needs both ends, and
removing one needs only the consumer.** The reasons are in the rulings below.

## The rules

A `rule KIND` block in the map says what that kind of change needs. Lines:

| Line | Met when |
| --- | --- |
| `approve affected all` | every person this kind's lines affect has approved |
| `approve affected N` | at least N of them have — or all of them, if fewer than N are affected |
| `approve affected P/Q` | approvals × Q ≥ P × (number affected) |
| `approve everyone all / N / P/Q` | the same, counted over every person in the map before the change |
| `approve others N` | at least N approvals from people this kind's lines do **not** affect |
| `waits DAYS` | today is at least DAYS days after `opened` |

A kind with no `rule` block in the map uses its default:

| Kind | Default rule | Why |
| --- | --- | --- |
| inside | `approve affected all` | It is your box. |
| holding | `approve affected all` | Nobody is put in a box without saying yes; nobody is kept in one. |
| wiring | `approve affected all` | Both ends of a new obligation agree to it. |
| boxes | `approve affected all` | Creating a vacant box costs nobody anything; its lines carry the rest. |
| doors | `approve affected all`, `approve others 1`, `waits 7` | It reaches people who are not in the room. |
| people | `approve affected all`, `approve others 1` | You join by saying yes and by somebody already here saying yes. |
| rules | `approve everyone 2/3`, `waits 30` | It changes everybody's rights. |

**A proposal is judged by the rules in the map before it is applied** — a
change to the rules is judged by the old rules.

**A rule cannot name a person.** There is no line in the vocabulary that says
"and Dana must approve", and there is deliberately no way to add one short of
changing this format. That is what makes executives obsolete in the data model
rather than in a slogan: the only standing anybody has comes from holding a box
a change touches, speaking for an outside party a change reaches, or being one
of everyone.

## History

An org that keeps `first.map` keeps a history: the map as it was founded,
followed by every applied proposal in order. **Replaying it must make
`org.map` exactly**, byte for byte. Where it does not, the map was changed
some way other than an agreed proposal — and in an organisation where every
change is meant to be a diff somebody agreed to, that is the one thing that
must never go unnoticed.

The order is the change number N on each `applied` line. The proposal tool
writes it (one more than the highest already there) when it applies a
proposal, because two proposals applied on one day to one block put their
added lines in the order they were applied, and a date cannot say which came
first.

Each step is judged **as it stood on the day it was applied**: its `applied`
line is set aside, and so is every answer dated after that day, and the rules
are the rules of the map at that point in the replay. An approval written in
afterwards does not make a change agreed retroactively.

| Code | Rule |
| --- | --- |
| H1 | `first.map` is a valid map. |
| H2 | Either every applied proposal carries a change number or none does. Some with and some without leaves the order unknowable. |
| H3 | Change numbers run from 1 to the number of applied proposals, each once. |
| H4 | In number order, the `applied` dates never go backwards. |
| H5 | Each change applies to the map the steps before it made: not stale, not broken, not invalid. A replay stops at the first that does not. |
| H6 | Each change was ready on the day it was applied, counting only answers dated that day or earlier. |
| H7 | The replayed map is `org.map`, exactly. |

| Code | Warns about |
| --- | --- |
| W4 | No applied proposal carries a number: the order is inferred from dates, then names. |

## The questions the vision asks, ruled on

Each is a first position, taken so the model can be built and argued with. The
ones that stay open are in [open questions](005-open-questions.md).

**Is it voted on?** Not by everyone, except for the rules themselves. A change
is accepted by **consent of the people it affects**, computed from its lines.
A majority of uninvolved people outvoting the two people who actually hold the
boxes is the failure this avoids; the people a change does not touch have
nothing to lose by it and nothing to say about it beyond objecting on the
record. The org's own rules, which touch everyone, are the one place everyone
counts — two thirds, and a month.

**Is there seniority?** No, and it cannot be added: no line records how long
anybody has been anywhere, so no rule can read it. Seniority is a proxy for
knowing a box. The map records the thing directly: whether you hold the box.

**Do we trust expertise; does it get more votes?** Holding a box is the
expertise the model recognises, and it gets you a say in every change that
touches that box — one say, the same as the other holders. Expertise that does
not hold the box is advice, and advice belongs in a proposal's `says` or an
objection's reason, where everybody can read it and it persuades on its merits.
Weighted votes would need a rule that names a person, which the format refuses.

**"What if that's my thing and you're making me do it differently and I don't
want to?"** Two rules, together:

1. **Nobody changes the inside of your box without you.** Its description, its
   fixed values, its `inside` map, who else holds it, what it needs, what it
   promises to produce — every one of those lines lists you as affected, and
   the default rules need every affected person.
2. **Nobody has to keep depending on you either.** A consumer may drop a wire
   from your box, or rewire their need to somebody else, without your consent:
   removing an `out` line affects the *consumer's* holders, not the producer's.
   An obligation taken away from you is not imposed on you.

So you can never be made to work differently; you can be routed around. That
is the same freedom in both directions, and it keeps one person from freezing
everyone downstream of them. Adding a wire *to* you needs you, because it is a
new obligation. And you can always leave: removing your own `held-by` line
affects only you. The box goes vacant and shows on the board with everything
waiting behind it.

**What about externalities that are hard to measure on a map?** The model
cannot measure them. It can refuse to let them go unnamed. **Anything that
crosses the org's boundary is a door, and every door names the outside party it
reaches** (M13). A change to a door needs, besides the people inside it
affects, an approval from somebody it does *not* affect — an outside eye — and
a week's wait so that people who are not watching have time to notice. An
outside party can have people who speak for it, and a door change needs them
too. The bakery's drain has Dee; the everglades should have somebody.

**What if engineers hide complexity and obfuscate their work?** Four things:

- **The kind of a change is computed, not claimed.** You cannot slip a rewire
  in as a wording fix.
- **A dependency that is not a wire is not an obligation.** Nobody can be
  blocked on something that is not on the map, so complexity that matters to
  anybody else has to surface as a wire to count.
- **An approval can name the change it approved** (the change id), so a
  proposal cannot be swapped out under the people who said yes to it.
- **Opacity is allowed and priced.** Work nobody else depends on is nobody
  else's business — the model does not demand anybody explain how they knead.
  But a box with one holder and a large reach on [the board](004-what-blocked-means.md)
  is visible as a risk, and a box may (and could be asked to) show its inside
  as a map of its own with `inside`.

**What if people stop working, go and frolic in the forest, or sit on the
couch?** Holding a box is voluntary, so the model compels nothing. What it does
is make the consequence impossible to miss: a vacant box, or one whose holder
is not delivering, sits on the board with a count of everything waiting behind
it, and everybody downstream can route around it without asking anybody's
leave. Whether the org pays people who hold nothing is not a question the map
answers — see [open questions](005-open-questions.md).

**What if nothing matters more than family time, and the family burns down the
everglades because of the mosquitoes?** That is a door. The everglades are
outside; the fire is an `out` port with `$everglades` on it; the change that
adds it is a doors change, and the family cannot accept it among themselves —
it needs somebody the change does not affect, a week of daylight, and whoever
speaks for the everglades. The model does not stop arson. It stops arson from
being an internal matter.

## Solutions considered

The vision asked for several solutions laid out. These are the ones weighed,
and how each could be written with the rule vocabulary if an org wanted it:

| Solution | Expressible as | Taken? |
| --- | --- | --- |
| Majority vote of everyone | `approve everyone 1/2` | Only for rules, and at 2/3. Lets the uninvolved overrule the involved. |
| Unanimity of everyone | `approve everyone all` | No. One person can freeze everything forever. |
| Consent of those affected | `approve affected all` | **Yes, the default.** Standing comes from holding what changes. |
| Lazy consensus: silence is consent after a wait | not expressible | No. Silence never counts — the person on holiday is the one who gets rewired. Routing around replaces it. |
| Seniority | not expressible | No. See above. |
| Weighted votes for experts | not expressible | No. Needs a rule naming a person. |
| An owner or executive decides | not expressible | No. That is what this replaces. |
| An outside eye on boundary changes | `approve others N` | Yes, for doors and for new people. |
| A cooling-off period | `waits N` | Yes, for doors (7) and rules (30). |
