# Strategem: Dynamic re-abstraction

A strategem is a data flow pattern that recurs across areas of the project
and has proven useful enough to name. This one is the owner's, given as
the answer to "which of several parts is at fault?" (issue 507).

> do a small audit of the functionality to ensure that we didn't design it
> wrong. If no fixes are required, then the code won't change. Compare a
> before/after checksum of just that component, and if it's the same for all
> three, then combine them into groups of 2 […] and try again. […] Once we
> identify the part that needs a fix, not what the fix is just the part that
> needs it, then we reduce our view again until we're within fixing range.
> Then we apply the fix. Dynamic re-abstraction.
>
> — the owner, 2026-09-27

## What it means

Look at the smallest part first. Widen the view only when the narrow look
finds nothing. Once the wide look names *where* — not *what* — narrow back
down to that one place, and fix it there. The width of the view follows
the evidence, in both directions.

## The shape

1. **Narrow:** each part alone. A look may change nothing, and "nothing
   changed" must be measurable — a checksum before and after — so a look
   that found nothing says so without being believed on its word.
2. **Stop early:** after every change, run the check again; passing ends
   the search, so innocent parts are left alone.
3. **Widen:** parts in pairs chosen at random (seeded from a record, so the
   same history gives the same pairs; an odd one out is already looked at),
   then larger groups, until one group holds everything. A wide look names a
   place and writes nothing.
4. **Narrow again:** the named part, with the wide look's finding in hand,
   within fixing range.
5. **Say when nothing was found.** The widest look finding nothing is a
   result, recorded, not a reason to guess.

## Examples in this project

- **A failing workflow (issue 507).** In the phase 5 demo's case four, three
  audits each found their part right; the pair 201+301, looked at together,
  named 201; the audit of 201 with that finding fixed it.
- **Describing a source (phase 4)** already has this shape without the name:
  one outline turn looks at the whole, then describe turns look at one
  issue each, and a failing issue is sent back alone with its findings.

## When not to use it

- When parts cannot be looked at alone (everything shares one state):
  start wide.
- When a look costs more than trying every fix: just try them.
