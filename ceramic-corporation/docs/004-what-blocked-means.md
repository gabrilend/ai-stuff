# 004 — What blocked means, and the board

The vision's promise is that **everyone can see what is blocking**. This page
defines what the blocked board computes, so that "what is blocking" has one
answer that any tool, or any person with a pencil, arrives at the same way.
The words *fed*, *ready*, *blocked*, *done* and *source* are defined in
[the org map](002-the-org-map.md#what-the-files-mean).

## A wait, and its source

A **wait** is an `in` port, on a box that is not done, that is not fed. Every
wait has exactly one **source**: the box at the other end of its wire, or the
outside party behind its door.

The board is about sources: **who is owed something, and by whom.** A person
looking at it is not asking "what is stuck?" — every stuck thing is visible on
the map already — but "what single delivery would unstick the most?"

## The three numbers

For each source X that is the source of at least one wait:

| Number | Is |
| --- | --- |
| **owes** | how many waits have X as their source |
| **frees** | how many blocked boxes have *only* X as the source of all their waits — the boxes that become ready the moment X delivers everything it owes, with nothing else changing |
| **reach** | how many boxes, other than X, **depend on** X: a box depends on X if one of its waits has X as its source, or has as its source a box that depends on X |

`frees` is what happens next; `reach` is everything that cannot finish without
X. **The board ranks by reach first**, because `frees` undercounts a chain: in a
stack of ten pull requests each built on the one before, the bottom one frees
exactly one — and nothing in the stack moves without it. Ties go to the larger
`frees`, then to a source that can act now, then by name.

**Loops are walked, not refused.** Depending on is followed with a visited set,
so a loop (the takings pay for the flour, which makes the loaves, which make
the takings) is counted once and the walk ends. A box that depends on itself
through a loop is not counted in its own reach.

## Can the source act?

| State | Means |
| --- | --- |
| **ready** | X is a box, every one of its own `in` ports is fed, and somebody holds it. It can deliver now. |
| **vacant** | X is a box with every input fed and nobody holding it. The delivery is waiting for a person, not for work. |
| **blocked** | X is itself waiting on something. Delivering it is not the next step; whatever X waits on is, and the board lists that too. |
| **outside** | X is an outside party. Nobody inside can deliver it; somebody can chase it. |

The board prints each source's holders beside it, so **one person holding a box
with a large reach** — the hidden-complexity risk [acceptance](003-how-a-change-is-accepted.md)
talks about — is visible without a separate report.

## The bakery's board

From [`examples/bakery/`](../examples/bakery/org.map):

| Source | State | Owes | Frees | Reach | Holders |
| --- | --- | --- | --- | --- | --- |
| cleaning | vacant | 1 | 1 | 2 | — |
| books | ready | 1 | 1 | 1 | dee |
| baking | blocked | 1 | 1 | 1 | ana |

Read top to bottom: the most useful thing anybody at the bakery can do is
scrub the bench, and nobody holds that job — which is what Cy's proposal is
about. Dee can release the oven budget today. Baking is owed by Ana and cannot
happen until the bench is clean, which the first row already says.
