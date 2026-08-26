# Phase 14 — The Instruments: progress

**The programs that read blueprints and check them. Seven of nine done.**

| ticket | file | state |
|---|---|---|
| `1401` | `091-units.lua` | done |
| `1402` | `092-expression.lua` | done |
| `1403` | `093-blueprint-reader.lua` | done |
| `1404` | `094-ledger.lua` | done |
| `1405` | `095-constraint-check.lua` | done |
| `1406` | `096-symbol-sweep.lua` | done |
| `1407` | `097-spec-report.lua` | not started |
| `1408` | `098-diagram-check.lua` | done |
| `1409` | `099-the-documentation-site.lua` | not started |

Numbered last and built first, and none of it ships to whoever builds the
machine. `097` and `099` both consume documents that do not exist yet — the
specification sheet and the bill of materials are phase 13 — so they wait.

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

## What is still open

`X1` in `009`: whether the constraint evaluator should grow interval arithmetic,
which is what carrying tolerances through the design would need. Every `measured`
value has a spread nobody is propagating, and that is `X2`.
