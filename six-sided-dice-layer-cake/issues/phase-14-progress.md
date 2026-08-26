# Phase 14 — The Instruments: progress

**The programs that read blueprints and check them. All eleven done.**

| ticket | file | state |
|---|---|---|
| `1401` | `091-units.lua` | done |
| `1402` | `092-expression.lua` | done |
| `1403` | `093-blueprint-reader.lua` | done |
| `1404` | `094-ledger.lua` | done |
| `1405` | `095-constraint-check.lua` | done |
| `1406` | `096-symbol-sweep.lua` | done |
| `1407` | `097-spec-report.lua` | done |
| `1408` | `098-diagram-check.lua` | done |
| `1409` | `099-the-documentation-site.lua` | done |
| `1410` | `100-the-phase-demonstrations.lua` | done |
| `1411` | the `solved` kind, and `103-the-set-counts-itself.lua` | done |

Numbered last and built first, and none of it ships to whoever builds the
machine. `102-the-cube-solved.lua` also lives here by nature and in phase 3 by
purpose; `304` and `305` own it, because what it answers is plumbing.

## What works

    ./run-checks

Loads every blueprint, resolves every symbol in dependency order, evaluates
every constraint, checks every drawing, and reports. Under a second. Writes
nothing except its own report.

    luajit src/096-symbol-sweep.lua .

Rewrites the companion page beside every blueprint, and names the ones that are
thin.

## What was learned building them

**A quantity must not be recognised by the identity of its metatable.** Two
modules each reaching for the units engine with `dofile` load it twice, and a
quantity built by one copy is then rejected by the other with a message saying
it is not a quantity. Correct, baffling, and the fix is a marker field.

**Zero belongs to every dimension.** The notation's rule is that every literal
is dimensionless, which is what stops an unlabelled physical quantity entering
the project. Taken without exception it also forbids `x > 0`, which is the
commonest constraint anybody writes. Zero is the one number that is dimensionally
neutral and the checker treats it so, narrowly.

**Unfinished and wrong want separate reports.** A constraint reaching for a
symbol nobody has declared yet is the normal state of a project under
construction, and putting it in the same list as a real failure means the real
failure gets skimmed past. It has its own heading and it does not fail the run.

**The declared unit is a second opinion and should be checked.** The ledger
compares what a derivation produces against the unit its author wrote down. That
was not asked for and it is the check most likely to catch a genuine confusion,
because a derivation that comes out in watts under a symbol declared in kelvin
is wrong in a way nothing else would notice.

**Write the constraint that cannot fail.** Euler's formula for a cube holds
identically. Writing it first proved four modules worked before anything with
physics in it was attempted, and it cost three minutes.

**A number a program produced needs a kind of its own.** Four kinds covered a
decision, a material property, an expression and a goal, and none of them fitted
the output of a solver. Written as a decision it invites a reader to change it by
preference; written as anything it goes stale the moment an input moves, silently,
while every constraint downstream goes on passing against a machine that no longer
exists.

The fifth kind is `solved`, and the label is not the point. The point is that the
declaration names the program, and the checker **re-runs that program on every
pass and fails the run if the copy has drifted by more than a part in a
thousand**. It reports in both directions: a declaration naming a program that
will not answer for it, and a program answering for a symbol nobody declared. Two
programs answer today — `102` for the cube's plumbing and `103` for the size of
the set — and between them they own twenty of the project's numbers.

**The set's description of itself had gone stale, and nobody could have noticed.**
`087` and `090` carried the blueprint count, the symbol count and the constraint
count as numbers a person had typed. Every one was wrong: eighty blueprints
offered where there were eighty-four, five hundred and eight requirements where
there were five hundred and forty-four. Nothing was wrong with the design; the
document was describing an earlier version of itself. `103` counts, the documents
copy, and the checker compares.

**A document that counts itself moves while you are counting it.** Converting
those five declarations from chosen to solved changed the number of chosen
declarations, so the first run reported the new figures as already stale — by
five, exactly the number that had changed kind. The second settled. It is a fixed
point and not a defect, and `090` says so in prose so nobody concludes the checker
is broken.

## What is still open

**The instruments have no companion pages.** The rule is that every source file
gets a `.info.md` beside it listing what it offers; `096` generates them for
blueprints and nothing generates them for programs. `102` and `103` have
hand-written ones. The other nine have none, and writing the generator is better
than writing nine files.

`X1` in `009`: whether the constraint evaluator should grow interval arithmetic,
which is what carrying tolerances through the design would need. Every `measured`
value has a spread nobody is propagating, and that is `X2`.

**The notation still cannot hold a list.** `solved` does not fix that — a program
answering with one number is not the same as the notation holding a set. Five
constraints still count where they should name, and `102` is the demonstration of
what the workaround costs: to check that twelve edges cross the parity, a whole
program had to be written and its answer copied back in as a scalar.
