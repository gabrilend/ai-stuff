# 1407 — The report

Produces `src/097-spec-report.lua`.

## Current behavior

Nothing. `089`'s specification sheet and `088`'s bill of materials are both
required to be generated and there is no generator.

## Intended behavior

**Produce the three documents whose content is entirely derived**: the
specification sheet, the bill of materials, and a full listing of every number in
the machine with its name, its unit, its derivation and its reason.

### The third one is the useful one

The sheet and the bill are for other people. **The full listing is for whoever is
working on the design**, and there is nothing else like it: several hundred
quantities, each with the expression that produced it and the sentence saying what
it is, sorted so that a reader can find one by name or walk them by phase.

`002` claims that naming every quantity buys the ability to print the machine with
its reasons attached. This is the program that cashes that.

### Templating over symbols

The sheet is a template with symbol names in it, and the generator substitutes
resolved values. If a name in the template does not exist, that is an error and not
a blank — `1303` requires that every figure on the sheet resolve to a symbol that
exists, and this is where it is enforced.

### Units for humans

A quantity resolved in base units is in metres and kilograms and looks absurd on a
specification sheet. The report must choose sensible units — millimetres for the
cube, watts for the power, terabytes per second for the bandwidth — and the choice
must be **declared in the template**, not guessed by the formatter, or the sheet
will say sixty thousand microns one day and change its mind the next.

### Reproducibility

Same input, same bytes out. No timestamps in the body; if a date is wanted it is
passed in. This matters more here than in `096`, because these documents are the
ones that get sent to people, and two copies that differ only by a timestamp
cannot be compared.

## What the file must offer

Render a template against the ledger. Produce the sheet, the bill and the full
listing. Report any template symbol that does not resolve. A dry run.

## Tests

- A template with a known symbol renders its value in the declared unit.
- An unknown symbol in a template raises and names it.
- The full listing contains every symbol in the ledger and nothing else.
- Two runs produce identical bytes.
- The bill of materials contains no literal quantities, only derived ones — which
  is `1302`'s constraint, checked by the generator that produces it.

## Blocks

`1302`, `1303`, `1304`.

## Blocked by

`1404`.

## Related documents

`002`. `089` and `088` are the templates this fills.
