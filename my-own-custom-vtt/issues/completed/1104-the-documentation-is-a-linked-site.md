# 1104 -- The documentation is a linked site

**Phase:** 11, the second view and the documentation
**Blocked by:** phase 10 complete.
**Blocks:** [1105](1105-the-site-is-built-by-a-tool.md)
**Documents:** [the table of contents](../../docs/table-of-contents.md)

## Current behaviour

**Done.** `103-build-documentation` writes 287 pages to `docs/HTML/`, each with
the whole table of contents down its left side.

Enough Markdown: headings, paragraphs, lists, tables, fenced code, inline code,
links, emphasis, block quotes and rules. Syntax highlighting for C, Lua and shell
at once, because their comment and string shapes do not collide.

The source is in the site too. The companion files say what each piece does; the
source pages are for the moment somebody wants to see how, without leaving to go
and find a checkout. Each links to the other.

### Where the crossing comes from

Explicit links are resolved against the source tree. Everything else is a guess,
made only on text that survived the earlier passes -- so never inside a link, and
never inside a code span that is not a module name.

A code span whose whole content is a module's name **is** a reference, because
that is how every document here writes one. Treating them as opaque left a
hundred mentions of `082-sprite` as dead ends.

Companions and their code are cross-linked by the tool rather than by hand, found
by name rather than by index: `023-blocks`, `024-test-blocks` and any
`0NN-blocks-main` belong together while sitting at three different places in the
reading order.

A dead link is marked on the page in red as well as reported. A link that quietly
becomes plain text is a link nobody ever fixes.

## Intended behaviour

**Every document reachable from every other**, as HTML in `docs/HTML/`, with a
table of contents down the left of every page.

### What goes in

| Kind | Why |
| --- | --- |
| `docs/` | The design. |
| `notes/` | The vision it came from. |
| `issues/` and `issues/completed/` | How it was built, step by step. |
| `src/*.info.md` | What each piece does, without reading the code. |
| `input/`, `output/`, `desire/`, `faith/`, `strategems/` | The project's own opening and closing statements, which are documents too. |

### Every mention becomes a link

An issue number mentioned anywhere becomes a link to that issue. A source file
mentioned anywhere becomes a link to its companion. A document's name becomes a
link to it.

**As many links as possible, embedded in the text**, because the value of a
documentation site over a directory of files is entirely in the crossing.

### The aesthetic is the project's

Dark, monospaced, unhurried. The same palette the browser view uses, because they
are the same project and a documentation site in somebody else's style is a
documentation site that reads like it belongs to somebody else.

### Code gets syntax highlighting

And it is highlighted by something that ships with the site rather than fetched
from a network. A page that reaches out to load a highlighter is a page that
breaks when the network does, and the whole point of the artifact is that it is a
directory you can open.

## Suggested implementation steps

1. Decide the page shape: contents on the left, content on the right, one file
   per source document.
2. Markdown to HTML, enough of it: headings, lists, tables, code, links,
   emphasis, block quotes.
3. Cross-reference resolution: issue numbers, file names, document names.
4. Highlighting for C, Lua, and shell, inline.
