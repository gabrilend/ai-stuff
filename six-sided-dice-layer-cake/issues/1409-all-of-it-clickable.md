# 1409 — All of it, clickable

Produces `src/099-the-documentation-site.lua`.

## Current behavior

Nothing. `docs/HTML/` is reserved and empty.

## Intended behavior

**Build the whole project as a cross-linked site**: every document, every
blueprint, every companion page, every ticket, reachable from every other, with the
numbers live rather than transcribed.

### What makes it worth building

Reading this project on disk means holding a number-to-file mapping in your head.
`037` is a blueprint, `1004` is a ticket, `009` is a document, and every one of the
hundred and eighty files refers to a dozen others by number alone. **On a page,
every one of those is a link**, and the difference in how fast somebody can move
through the design is large.

### What each page carries

Its own content, rendered. Every number reference turned into a link. **A list of
what points at it**, which does not exist anywhere on disk and is the thing that
makes a design navigable in both directions. For a blueprint, its symbols with
their resolved values pulled from the ledger at build time — so the site is never
out of date with the design, because it is built from the same source the checker
reads.

### What the front page carries

Counts, taken during the build: blueprints, symbols, constraints, how many hold,
how many `target` kinds remain, how many open questions and how many answered.
**A project's front page should tell you what state it is in**, and all of those
are known at build time.

### The toys

`002`'s notation makes something possible that a static document set cannot do: a
reader can change a number and see what breaks. A slider on `012`'s eleven given
lengths, re-resolving the ledger in the browser and showing which constraints go
red, is the single most valuable interactive thing this project could have — it
turns the design from a document into a thing you can push on.

That needs the ledger's resolution to run in the browser, which means either
porting it or exporting the dependency graph and evaluating it in script. **The
second is much less work** and the blueprint should take it: export the graph as
data, evaluate in the page.

### The rule

**Built, never edited.** Nothing under `docs/HTML/` is a source file, it is
ignored by version control, and the builder is the artifact. Every page says so in
its footer, because somebody will otherwise fix a typo in the wrong place.

### Style

One aesthetic across every page, matching the project: plain, dimensioned, more
like a drawing sheet than a web page. Syntax highlighting on the notation blocks.
The drawings in a monospace face that does not break the box-drawing characters,
which is a real constraint and worth stating because most do.

## What the file must offer

Build the site from the repository. Report what it wrote and the counts. A check
mode that verifies every internal link resolves without writing anything.

## Tests

- Every number reference in every source file becomes a resolving link.
- The what-points-at-me list is the reverse of the link graph.
- The front page counts match what `095` reports.
- Two builds produce identical output.
- Check mode finds a deliberately broken reference.
- The exported dependency graph re-resolves in the browser to the same values the
  ledger produced.

## Blocks

Nothing.

## Blocked by

`1404`, `1405`, `1406`.

## Related documents

`002`. Every file in the project is an input.
