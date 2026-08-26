# 1303 — The one page somebody reads

Produces `src/089-specification-sheet.md`.

## Current behavior

Nothing. There is no single page that says what this machine is and what it does.

## Intended behavior

**One page. Generated, not written.** Every figure on it pulled from the ledger by
`097`, so that it cannot disagree with the design it describes.

### What goes on it

| | |
|---|---|
| **Physical** | edge length, mass, volume, mounting |
| **Power** | input voltage and current, total dissipation, at three operating points |
| **Cooling** | fluid, flow, pressure, inlet temperature, heat rejected |
| **Memory** | usable capacity, aggregate bandwidth |
| **Compute** | operations per second, at the stated numeric format |
| **Storage** | line count, aggregate, model load time |
| **Output** | spout grade, width, pane size, whole-core transfer time |
| **Performance** | tokens per second single-stream and aggregate; prompt rate |
| **Model** | largest that fits, at stated context and batch |
| **Life** | target, and the annual replacement rate implied |

### The two numbers on it that mean the most

**Tokens per second, single stream.** What one person waits. About eleven hundred
for the reference model, and the surprising part is that the six-stage pipeline
costs almost nothing to get it.

**Largest model that fits.** Seventy billion parameters at four bits, at the stated
context and batch — and the cliff past it is sheer, because `804` chose refusal
over degradation. **The specification sheet must say that**, because a
specification that gives a maximum without saying what happens beyond it invites
somebody to try.

### What a good specification sheet also does

**Says what it is not.** No operating system, no protection, no general purpose
computing, no training beyond low-rank adaptation, unremarkable capacity next to
its bandwidth, and no field-serviceable parts. Five sentences, and they save
everybody a month.

**Names its own assumptions.** Every figure here is for the reference model at the
reference context and batch. A different model gives different numbers and the
sheet must say where to find them, which is `078`'s surface and `080`'s
sensitivity table.

**Gives the comparison honestly.** Twelve to one on memory bandwidth against an
accelerator with high-bandwidth memory, which is the win. Unremarkable on
capacity, which is not. Both.

### Why generated

Because a specification sheet is the document most likely to be copied into a
slide, quoted in an email, and believed a year after it stopped being true. If it
is regenerated from the ledger every time, the copy in the slide is at least wrong
in a way somebody can date.

## Symbols this must publish

Nothing new. This blueprint consumes and publishes no symbols of its own, which is
unusual and should be stated — it is a view, and a view that invents a number has
a bug.

## Constraints this must assert

- Every figure on the sheet resolves to a symbol that exists elsewhere. Enumerated,
  because the failure mode of a summary document is a number that appears only in
  it.
- The sheet declares no symbols of its own.
- The operating point every figure is quoted at is stated on the sheet.

## Suggested implementation steps

1. Write it as a template over symbol names.
2. Write the "what it is not" section, in five sentences, before the figures.
3. Add the assumption statement and the pointers to the surfaces.
4. Give both halves of the comparison.

## Blocks

`1304`.

## Blocked by

`1301`, `1302`, and through them everything.

## Related documents

`000` is the long version of this page. `080` and `078` are where the sheet's
figures come from.
