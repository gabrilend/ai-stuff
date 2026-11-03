# 101 — The model is written down

| | |
| --- | --- |
| Phase | 1 — The model, and the tools that read it |
| Blocked by | — |
| Blocks | 102, 103, 104, 105, 106 |
| Reads | [the vision](../../notes/vision) |

## Current behavior

The project is one file, the vision. It describes an organisation run as a
soramech map everyone can see, lists the questions about how changes get
accepted, and says the data model must be "precisely defined". Nothing defines
it.

## Intended behavior

A specification precise enough that two people writing two tools get the same
answer: what an org's files look like, what every line means, when a box is
blocked, what a change proposal is, how it is applied, and who must agree to
it. Every rule carries a code a tool can cite. The vision's open questions are
answered as rulings with reasons, and what is left is listed with working
rulings. A worked example the documents and tests share.

## Suggested implementation steps

1. Set the project up the way the monorepo's young projects are: README,
   `notes/vision`, LICENSE and COPYING, `docs/` with a table of contents and a
   roadmap, `issues/` with a progress file, the index counter.
2. Read soramech off the monorepo (soren-ds's runtime document above all) and
   write down what is borrowed and what is not.
3. Write the grammar, the map, the state; then proposals, kinds of change,
   who is affected, the rules and their defaults; then the board.
4. Write the bakery example and read it by hand against the definitions.

## What Happened

Built as documents 001 to 006 and `examples/bakery/`. The decisions, each with
its reason in the documents:

- **Three files, not one.** `org.map` (structure, changes only by proposal),
  `org.state` (fed ports and finished work, changes daily by whoever waits),
  `proposals/*.proposal`. A diff of the map is then always a change to the org.
- **Soramech's line rules kept:** first word a keyword, second a name, so no
  word is reserved; wires written at both ends, so a wire change always shows
  both parties in the diff; fixed values; `$` doors; readiness read off ports;
  loops are not errors. **Not kept:** types and widths, the one-output rule (a
  role produces several things).
- **Every need has exactly one source** (M9), so "is this blocked" has one
  answer.
- **A proposal is a structural diff** — `add`/`edit`/`remove` blocks of `+`/`-`
  lines — not a unified diff, so it does not depend on line order or context,
  and a stale proposal (the map moved under it) is detected exactly.
- **Status, kinds and affected people are derived, never declared.**
- **Acceptance is consent of the affected**, per kind of change, with
  defaults; rules are data in the map, judged by the rules before the change.
- **A rule cannot name a person** — no executives, no weighted votes, no
  seniority, by construction.
- **Adding a wire needs both ends; removing one needs only the consumer.**
  Nobody changes your box without you; nobody has to keep depending on you.
- **Doors name their outside party**; door changes need an outside eye and a
  week; outside parties may have speakers.
- **Approvals may carry a change id** (FNV-1a of the change) so a proposal
  cannot change under the people who approved it.
- **The board ranks by reach before frees**, because frees undercounts a chain.

The vision's own file moved from the project root to `notes/vision`, where the
monorepo's recent projects keep it. The parent paths it names
(`minimal-soramech`, `ceramic-trainstation`) are not on this machine; the
reading of soramech is recorded as an assumption (open question Q1).
