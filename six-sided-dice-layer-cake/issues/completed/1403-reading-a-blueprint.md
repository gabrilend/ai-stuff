# 1403 — Reading a blueprint

Produces `src/093-blueprint-reader.lua`.

## Current behavior

**Done.** `src/093-blueprint-reader.lua` exists. Four block kinds -- meta,
symbols, constraints, drawings -- held in a dispatch table, each accumulating
across repeated blocks so a long blueprint can put its symbols beside the prose
that introduces them.

It refuses rather than guessing: a symbol line with four fields, an unknown
kind, a `given` carrying an expression, a constraint with no reason, a drawing
with no caption, an unclosed fence. Every refusal names the file and the line.

**One change from the ticket.** A drawing keeps its blank lines and its leading
spaces, because in a drawing those are the picture. Everywhere else they are
formatting and are dropped.

## Intended behavior

**A reader that turns one blueprint file into a structure**: its metadata, its
declared symbols, its constraints, and its drawings.

### What it extracts

From the `meta` block: the phase, and the issues that describe this file.
From the heading: the number and the title.
From every `symbols` block: name, unit, kind, value or expression, meaning.
From every `constraints` block: tag, relation, reason.
From every `drawing` block: the caption, the body, and every bracketed symbol name
in it, which `098` checks.

Blocks may appear more than once in a file, because a long blueprint is better read
with its symbols beside the prose that introduces them than gathered at the end.
The reader must accumulate rather than take the first.

### Strictness

**Refuse rather than guess.** A line in a `symbols` block with four fields instead
of five is an error naming the file and the line, not a symbol with a missing
meaning. A kind that is not one of the four is an error. A `given` whose fourth
field is not a bare number is an error.

This is the project's own rule about fallbacks applied to its own tooling: a reader
that tolerates a malformed declaration produces a ledger that is quietly missing
something.

### What it must not do

Evaluate anything, resolve anything, or look at any other file. One file in, one
structure out, no dependencies. `094` is where files meet each other, and keeping
that separation is what makes the reader testable on a fixture.

## What the file must offer

Read a path and return the structure. Read a string, for testing without a file.
A description of the structure's shape, in the companion page, precise enough that
`094`, `096`, `097` and `098` can all consume it without reading this source.

## Tests

- A fixture blueprint with two of every block type parses completely.
- Repeated blocks accumulate.
- A four-field symbol line raises with the file and line.
- An unknown kind raises.
- A `given` with an expression raises.
- Bracketed names are extracted from drawings, including several on one line.
- A file with no `meta` block raises.

## Blocks

`1404`, `1406`, `1407`, `1408`, `1409`.

## Blocked by

`1402`.

## Related documents

`002` for the format this implements. It is the normative description and this
reader must not extend it quietly.
