# 090 — What a materials engineer receives

```meta
phase  | 13
issues | 1304
```

## The list that matters, first

**What this design does not tell you.** It is at the front rather than the back
because it is what a recipient most needs and least expects.

**No tolerances.** Every number in this project is a point value. A materials
engineer will ask for the tolerance on the cube edge on the first day and the
honest answer is that nobody wrote one down. `009` entry X2. **This is the single
largest omission.**

**No supplier or process qualification.** Three nodes are named and none is
qualified. Nobody has confirmed a line will run the cold plate's etch, though
`081` at least checks the aspect ratio against a stated capability.

**No thermal or mechanical simulation.** The thermal chain is one-dimensional hand
analysis. Nothing has been meshed.

**No signal integrity extraction.** `051` and `063` are budgets, not simulations.

**No price.** `088` gives structure and sensitivity, deliberately.

**Two pieces of software are assumed and not specified.** `058`'s packer, which
turns a trained model into the media layout, and `085`'s reference implementation,
which rung nine compares against bit for bit. **Bring-up needs both on day one.**

**Nothing has been built or measured.** Every number is derived. **Consistent is
not correct and correct is not manufacturable.**

## The contents

The eighty blueprints and their companion pages. The instruments and their
report. The documentation, chiefly the five datapaths and the honest departures
page. The bill of materials and the specification sheet. The bring-up procedure.
**And the open questions page, in full and unedited.**

## The reading order

Not the numeric order.

```drawing
what to read, and why [not-dimensioned]

   000   what the object is                        five minutes
   003 to 007  one journey each: a token, a weight, a joule,
         an ampere, a pane of bits leaving          the fastest route in
   008   the six places the original idea was overruled,
         each with the number that overruled it
   012   the eleven chosen lengths                  the shortest path to
                                                    what is actually decided
   your own phase
   009   before doing anything
```

## How to use it as a machine rather than as drawings

This package **checks**. `095` loads every blueprint, resolves every symbol,
evaluates every constraint and reports, in under a second.

That makes it a different kind of document from a set of drawings, and the worked
example is the thing to try first: **change the compute die's edge from
twenty-four millimetres to twenty-six and run it again.** The report names the
core-edge constraint — because the core's size is derived one way from the outside
of the cube and another way from the memory stack inside it, and nothing forces
those two arguments to agree.

That is what this package offers that a folder of drawings does not.

## Symbols

```symbols
n_omission    | 1 | given | 7        | things this design does not tell a recipient, listed at the front
n_content     | 1 | given | 7        | kinds of thing in the package
n_read_step   | 1 | given | 6        | steps in the reading order
n_software    | 1 | given | 2        | pieces of software assumed and not specified
n_worked_eg   | 1 | given | 1        | worked examples of using the package as a machine

n_bp_pkg      | 1 | derived | n_bp                       | blueprints delivered
n_sym_pkg     | 1 | solved | 1443                        | symbols in the ledger -- from 103. This was a hand count of something the ledger knows exactly, and it was wrong by fourteen before anybody looked
n_con_pkg     | 1 | derived | n_constraint               | constraints
n_open_pkg    | 1 | solved | 0                           | symbols still carried as targets rather than derivations -- from 103. None: the last one was 019's service time, which became the sum of nine steps rather than one number nobody could take apart
n_solved_pkg  | 1 | solved | 22                          | symbols a program produced because no expression in this notation could -- from 103
n_q_blocking  | 1 | given | 2                            | blocking open questions in 009
n_q_open      | 1 | given | 18                           | open questions altogether: the two blocking ones and sixteen carried. A hand count of 009's headings, and the one figure in this package that a program still does not produce
f_derived     | 1 | derived | (n_sym_pkg - n_given_pkg) / n_sym_pkg | share of the project's numbers that are worked out rather than chosen or measured
n_given_pkg   | 1 | solved | 593                         | symbols that are chosen or measured rather than worked out -- from 103: four hundred and seventy-three a person decided and a hundred and sixteen taken from a datasheet
```

## A document that counts itself moves while you are counting it

The five figures above describing the size of this project were hand counts
until `103` was written, and every one of them was wrong: eighty blueprints
offered where there were eighty-four, five hundred and eight requirements where
there were five hundred and forty-four. Nothing had gone wrong with the design.
The document was describing an earlier version of itself, which is what a
self-describing document does if nobody re-counts.

Handing the counting to a program has an odd consequence worth writing down.
Converting these five declarations from *chosen* to *solved* changed the number of
chosen declarations in the project, so the first run after the change reported
that the new figures were already stale — by five, which is exactly how many
declarations had just changed kind. The second run settled.

That is a genuine fixed point and not a defect: a statement about a set, held
inside the set, has to be consistent with itself. It converges in one pass because
adding a statement about the count changes the count by a known amount. It is
worth knowing before somebody meets it and thinks the checker is broken.

There is a second, milder consequence and it is worth naming as a cost rather
than hidden. These five figures are unlike every other computed value in the
project: the ones describing the cooling network only move when something about
the cooling changes, but a count of the set moves when **anything anywhere**
changes. Adding one requirement to one blueprint makes two of these stale, and the
checker says so, and somebody has to copy two numbers.

That is the mechanism working, and it is a real tax on a large edit. The
alternative — reading the count live and never writing it down — costs more: a
figure nobody can see in the document is a figure nobody can check the document
against, and the whole reason these five exist is that a covering note offering
eighty blueprints when there are eighty-four is worse than one offering none.


## Constraints

```constraints
C-090-1 | n_omission >= 7             | at least seven omissions must be listed. Asserted as a floor rather than a ceiling, deliberately: the failure mode of a handoff package is a shorter list than the truth, and this is the constraint that makes shortening it a violation
C-090-2 | n_bp_pkg == n_bp            | every blueprint in the set is in the package
C-090-3 | n_con_pkg == n_constraint   | and every constraint
C-090-4 | f_derived > 0.55           | most of the project's numbers must be derived rather than chosen. It comes out at about four in seven, which is the claim the whole notation exists to make good, reduced to a fraction -- and the remaining three in seven are the material properties, the process figures and the eleven lengths somebody decided
C-090-5 | n_worked_eg >= 1            | there must be at least one worked example of changing a number and watching what breaks, because that is what this package offers that drawings do not
C-090-6 | n_software == 2             | exactly two pieces of software are assumed and not specified. Asserted as a value so that a third arrives named rather than assumed
C-090-9 | n_open_pkg == 0              | no symbol in the package may still be a goal rather than an answer. This is the constraint that says whether the design is finished, and it is the one currently failing -- 019's service time waits on a procedure that has to exist before it can be timed
C-090-10 | n_solved_pkg < n_sym_pkg / 10 | fewer than a tenth of the project's numbers may come from a program rather than an expression. Not because programs are worse, but because a number in a program is a number a reader has to run something to see, and a design that is mostly opaque to reading has stopped being a set of blueprints
```

## What is still open

**The ownership table the ticket asked for is not here.** Which blueprint a
question about a given subject goes to, and which open question bears on it. It
is the part that makes the package usable by somebody who did not write it, and
it wants generating from the tickets' related-documents sections rather than
writing.

**`n_sym_pkg` and `n_given_pkg` are hand counts** of things the ledger knows
exactly. They are the last two numbers in the project that should be derived and
are not, and `097` is what would supply them.
