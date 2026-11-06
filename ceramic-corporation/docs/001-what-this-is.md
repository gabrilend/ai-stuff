# 001 — What this is

An organisation written down as a map of boxes and wires that everyone in it
can read, where anyone can see what is blocking and anyone can propose a change
to how the organisation works — as a diff, the way a change to a program is a
diff. There is no executive, because there is nothing left for one to do that
the map does not already show.

The vision is in [notes/vision](../notes/vision), in the author's own words. It
says the display matters little ("people can design their own UIs") and the data
model underneath matters most, and that the data model has to be "precisely
defined". This project takes that literally: **the product is a file format and
the rules for changing it**, plus a few small tools that read it. Any view —
the boxes-and-wires picture the vision wants, a board of blockers, a static
page — is a reader of the same files.

## The vocabulary

| Word | Means |
| --- | --- |
| **org** | One organisation: a directory holding a map, a state file, and proposals. |
| **map** | `org.map`. The structure: who is in it, what boxes exist, what flows between them, what crosses the boundary, and the rules for changing all of that. Changes only by an accepted proposal. |
| **box** | A unit of responsibility. A **role** is ongoing (baking). A **work** box is finite and can be finished (replace the oven). |
| **holder** | A person who answers for a box. A box with no holder is **vacant**. |
| **port** | A named thing a box needs (`in`) or produces (`out`). |
| **wire** | An `out` port of one box feeding an `in` port of another. Written at both ends. |
| **fixed value** | An `in` port that is always satisfied: a recipe, a standing agreement. |
| **door** | A port that crosses the org's boundary to or from an **outside** party: customers, a supplier, a river. Externalities live here. |
| **state** | `org.state`. Which `in` ports currently have what they need, and which work boxes are done. Changes every day, by the people waiting, without a proposal. |
| **fed** | An `in` port that currently has what it needs. |
| **ready / blocked** | A box is ready when every `in` port is fed, blocked when one is not. |
| **proposal** | The org's pull request: a file of line edits to the map, plus the answers people give it. |
| **kind of change** | What a proposal's lines touch — inside one box, holding, wiring, boxes, doors, people, rules. Derived from the diff, never declared. |
| **affected** | The people a change touches, derived line by line. Their approval is what acceptance is mostly made of. |

[The org map](002-the-org-map.md) defines every one of these exactly.

## What soramech is, as this project reads it

The vision says the structure is "based on soramech" and points at
`minimal-soramech` and `ceramic-trainstation`, two directories on the author's
own machine that are not in this repository. What follows is **an assumption**,
read off the places in the monorepo that describe soramech —
`soren-ds/docs/012-soramech-runtime.md` above all, and the soren-ds,
supcom-derivative-clone and every-software-image-able notes that lean on it. If
the parent project says otherwise, the parent project is right and this section
and [the org map](002-the-org-map.md) should follow it.

Soramech is a way of writing a program as a map of **boxes** placed as
**stations**, joined by **wires** from output ports to input ports. Its rules,
and what this project takes from each:

| Soramech | Here |
| --- | --- |
| A station fires when every input port holds a value. There is no scheduler and nothing polls; readiness is checked when a value arrives. | **A box is ready when every `in` port is fed.** Blocking is not a status somebody sets; it is read off which ports are empty. |
| The map is one line-oriented text file. The first word of a line is always a keyword and the second always a name, so no word is reserved and the format can grow. | Same, for `org.map`, `org.state` and proposals. |
| Every wire is written at both ends, so reading one station tells the whole truth about it. | Same. And because a change to a wire is two changed lines, **both parties to it appear in the diff**, which is what lets acceptance be computed from the diff. |
| A fixed-value port holds a constant written into the map. | Same: standing agreements, recipes, policies a box runs on. |
| A `$` on a port is a door: the program's outside delivers or receives there. | Same, and the outside party is named. This is where externalities go. |
| A map is a box: a program with doors can be placed inside another. | An optional `inside` line points a box at another org directory. |
| A station with no source can never become ready, and costs nothing while it waits. A failing box takes itself out of service and the hole stays visible. | A vacant box, or one whose holder does not deliver, stays on the map and shows on the board with everything waiting behind it. Nothing is deleted to hide it. |
| A loop is not an error; there is no cycle detection and there must not be. | Same. Organisations are full of loops (the takings pay for the flour). The board walks them without falling over. |
| Being an argument slot is *derived, not stored*, so it cannot go stale. | Proposal status, kinds of change, affected people and blocked-ness are all derived. The only stored facts are the ones a person attests. |

What does **not** carry over: types and byte widths (a wire here carries a thing
people name, not a C value), the catalogue, the compile pipeline, and the rule
that a station has one output port — an organisational role produces several
distinct things, so a box here may have several named `out` ports.

## What this is not

It is not a payroll system, a legal entity, or a project tracker with tickets.
It does not decide what anyone is paid or how a dispute outside the map is
settled; [open questions](005-open-questions.md) lists those, each with the
working ruling taken so far. It is the shared, diffable picture of who needs
what from whom, and the rule for changing that picture.

## Where it is tried on itself

The monorepo this project lives in has the shape the vision describes: many
projects, one person who merges, and a long queue of pull requests some of which
are stacked on others. [The roadmap](006-roadmap.md) ends phase 1 with that
queue written as an org map and the blocked board telling its one merger which
merge frees the most work.
