# 305 — The documentation as a website

## Current behavior

Done. `src/033-the-documentation-site.lua` builds the site; every link it emits
is checked against the pages that exist, and the build fails if any does not
resolve.

The markdown converter handles what this project's writing uses and the code
blocks are coloured by a scanner rather than by substitution — a substitution
that colours keywords will happily colour the word `end` inside a comment.

There is one thing on the site that is not a document: the blur radius is the
most important number in the project and the paragraph explaining it is worse
than seeing it, so a character is rendered at a spread of radii and a slider
moves between them. Both failures either side of the right answer can be looked
at instead of described.

The companion pages are generated separately: `src/034-the-companion-pages.lua`
sweeps `src/`, lifts each file's header block and each of its function folds,
and writes the `.info.md` beside it. It was built early because every source
file needs one from the moment it exists, and twenty-odd pages written by hand
would have been stale before the phase ended. `--check` reports what is out of
date and writes nothing, which is what `run-tests` calls.

That works because every function in this project is wrapped in a fold naming
it, with its explanation underneath. The convention was there for editing
comfort; this makes it load-bearing.

## Intended behavior

**Every document, every ticket and every source file's companion page, as one
cross-linked site, built rather than written.**

`docs/HTML/`, gitignored, produced by a program. Every page is derived from a
file already in this repository, so tracking the output would put the same words
in the record twice and make one documentation edit look like fifty.

What makes it worth having over the markdown it came from:

**Every reference is a link.** `docs/004` written in prose becomes a link to that
page. `202` becomes a link to that ticket. `src/016-the-grey-canvas.lua` becomes a
link to its companion page. Those references are already everywhere in this
project's writing and following one currently means opening a file manually.

**A contents column that is always there**, so any page reaches any other.

**The companion pages are reachable from anywhere their file is mentioned.**
Every source file has one (`docs/006`); they are the right level of detail for a
specific question and are currently the least discoverable thing here.

**Things to touch.** The knobs in `docs/balance-updates.md` are numbers with
ranges and consequences, and a slider that shows what a blur radius of 4 versus
14 does to a real character is a better explanation than the paragraph. The
stroke-order arrows can step. The biome table can be browsed as a table.

**Syntax highlighting for the Lua**, because code embedded as grey text is code
nobody reads.

## Suggested implementation steps

1. **`src/033-the-documentation-site.lua`** — walk `docs/`, `notes/`, `issues/`
   and the `.info.md` files; convert; link; write. The companion pages are
   already produced by `src/034-the-companion-pages.lua`; this renders them
   alongside everything else rather than regenerating them.

2. **The markdown converter handles what this project's documents use** —
   headings, paragraphs, lists, tables, fenced code, inline code, emphasis, links,
   block quotes — and errors on anything else rather than passing it through as
   text. A converter that silently drops a construct produces a page that is
   quietly missing a paragraph.

3. **Cross-references are found by pattern**, on the conventions already in use:
   a bare three-digit number is a ticket, `docs/NNN` is a document, a
   `src/NNN-name.lua` is a source file. Those conventions exist and are already
   followed, so the linking is a consequence of the naming rather than a new
   obligation.

4. **One stylesheet, shared with the gallery in `304`.**

5. **Test that every generated link resolves.** A site full of dead links is worse
   than the markdown, because markdown does not promise the link works.

## Related

`docs/table-of-contents.md` — the hierarchy this renders. `304` — the shared style.
