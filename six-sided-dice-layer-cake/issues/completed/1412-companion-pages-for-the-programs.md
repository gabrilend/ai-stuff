# 1412 — Companion pages for the programs

Produces `src/104-the-programs-described.lua`.

## Current behavior

**Done.** `src/104-the-programs-described.lua` exists and writes a page beside
every program. The count of public entry points with nothing said about them is
zero on every run.

**The sweep's first honest report was the point of building it.** Twenty-three of
fifty-six public entry points had no description anywhere — `094`'s `load` among
them, which is the ledger's entire interface and the function every other program
calls. Forty per cent of the instruments' surface was undocumented and nothing in
the project could have told anybody.

**Two of its findings were the tool being wrong, and both were fixed before any
page was written.** Most modules define a function privately, describe it there,
and assign it to the module table at the bottom of the file — so the first version
reported nine of `102`'s twelve exports as undocumented when their prose was
sitting on the private names. And a public constant has no fold at all, so its
description is whatever comment block sits above it. Neither was a defect in the
source. A documentation tool that cries wolf gets ignored, so the rule is that a
reported gap has to be a real one.

**One page exposed two more parser faults on sight.** The units engine's ten
dimension slots claimed to be published from a function called `m` — the table
literal's first element read as an alias — and the dimensionless constant claimed
to take an argument, because `newdim()` was read as an alias to `newdim`. Only a
bare name on the right of an assignment is another name for something; a table or
a call is a value in its own right.

**The convention it reads holds everywhere.** Zero broken folds across a hundred
and three of them: none without a definition, none whose name disagrees with the
definition it opens.

## Intended behavior

**One `.info.md` per program, generated from the program's own source.**

### Why this is possible at all

Lua has no declaration of what a module exports beyond whatever it happens to
assign to its return table, and reading that reliably means running the file or
parsing the language. Neither is wanted here.

What makes it tractable is a convention this project already imposes for a
different reason. Every function is wrapped in a vimfold, opening with a comment
carrying the function's name without arguments, and the definition with arguments
on the line below:

```
-- {{{ function M.load()
-- Load every blueprint under src/, resolve every symbol in dependency
-- order, and report what would not resolve.
function M.load(dir)
```

That is three pieces of structured data in a shape a program can read: the name,
the prose, and the argument list. The fold convention was adopted for editing
comfort and turns out to be a machine-readable interface declaration. **The
generator should say so on every page it writes**, because a convention that
earns something unintended is worth knowing about.

### What a page carries

- **What it is.** The file's own header comment, which every program already has
  and which is already written for a general reader.
- **What it offers.** One row per public entry — `function M.name(args)` and
  plain `M.name = ...` assignments — with the argument list and the fold's prose.
- **How it works inside.** The private functions by name and one line each. Not
  their bodies: a companion page treats a function as a black box, and this
  section exists so a reader knows what is in the file, not how.
- **What it reads.** The other programs it loads, which is the dependency edge
  no single file can see from inside itself.
- **Whether it runs.** Programs here are both loadable and runnable; the page
  should say which, and give the command.

### What it must refuse to do quietly

**A public function outside a fold is a defect and must be reported**, not
skipped. The whole method rests on the convention holding, so the generator is
also the convention's enforcement — it should count what it could not see and say
so, in the same way `096` names blueprints that are thin.

**A fold whose name disagrees with the definition below it** means somebody
renamed one and not the other, and the page would then be describing a function
that does not exist under that name.

### Determinism

Same as `1406`: no timestamps, no run identifiers, entries in source order. Two
runs produce identical bytes, so a change to a page means a change to a program.

## Why a second generator rather than extending 1406's

`096` reads blueprints, which are markdown with declaration blocks in a notation
this project defined. This reads Lua. The two share an output shape and nothing
else, and the input halves have no common ground to abstract over.

They also have different audiences. `090` is explicit that the instruments do not
ship to whoever builds the machine, so blueprint pages are part of the
deliverable and program pages are not. Putting both in one tool would mean one
program writing into both halves of that line.

## What the file must offer

A run over a directory. A dry run that reports without writing. A count of pages
written, and a report of every public entry it could not see.

## Tests

- Every program in `src/` gets a page.
- A function inside a fold appears with its argument list and its prose.
- A public function outside a fold is reported and not silently dropped.
- A fold naming a function the definition below does not define is reported.
- The two hand-written pages are replaced by generated ones carrying at least
  what they carried.
- Running twice produces identical bytes.

## Blocks

Nothing. This is documentation of work already done.

## Blocked by

Nothing. The convention it reads has been in place since `1401`.

## Related documents

`1406` is the same idea for blueprints and the format to match. `002` for why a
thing is written once. `009` carries this as an open question under the
instruments.
