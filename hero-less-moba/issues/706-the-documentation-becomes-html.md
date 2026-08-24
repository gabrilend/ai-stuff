# 706 — The Documentation Becomes HTML

| | |
| --- | --- |
| Phase | 7 — Watching It Happen |
| Blocked by | — |
| Blocks | — |
| Reads | [the viewing layer](../docs/017-the-viewing-layer.md), docs/table-of-contents.md |
| Open questions | none |

## Current behavior

The documentation is Markdown files in a directory. Reading it means opening
files one at a time and following relative links in a text editor.

## Intended behavior

A generated, browsable copy of everything under `docs/HTML/`: one shared
stylesheet, a table of contents down the left side of every page, and **every
document reachable from every other**.

The same separation the whole project is built on, applied to its own
documentation. **The Markdown is the data; the HTML is a view of it**; a tool
produces the view. Nothing under `docs/HTML/` is ever edited by hand, and if a
page is wrong the fix is in the Markdown or in the generator.

What the generated pages carry beyond the prose:

- **Syntax-highlighted code**, wherever a document quotes any.
- **Dense internal linking.** Where a document names another document, a source
  file, or an issue, that is a link — to the section, not just the page. Where it
  names a source file, the link goes to that file's companion `.info.md` page.
  Where it names an issue by number, the link goes to the issue.
- **The `.info.md` companions**, reachable everywhere their file or its functions
  are mentioned.
- **Charts, sliders, and toys.** The balance tables want sliders; the map wants a
  diagram you can drag; the milestone system wants an interactive lane you can
  push a frontline along. Documentation about a simulation should let you poke at
  the simulation.
- **The project's own aesthetic**, consistent across every page.

## Suggested implementation steps

1. Write the generator: Markdown to HTML, one stylesheet, a table of contents
   built from `docs/table-of-contents.md`.
2. Write the cross-reference pass: resolve document names, issue numbers, and
   source file names into links, and **fail loudly on an unresolvable reference**
   rather than emitting a dead link. A broken link in generated documentation is
   a bug in the source Markdown and should be reported as one.
3. Write the `.info.md` pages into the same tree with the same navigation.
4. Add the interactive pieces, starting with a lane diagram that shows push
   depths and milestones, since that is the concept most people will find
   unfamiliar.
5. Wire the generator into the build so the HTML is never stale.

## Related documents and tools

- [The viewing layer](../docs/017-the-viewing-layer.md)
- `docs/table-of-contents.md`

## Note

This issue has no blockers and can be done at any point. It is filed in phase 7
because it is a viewing concern, not because it has to wait. Doing it early would
make every later phase easier to read, and the cross-reference validator would
catch broken links in the documentation from the day the documentation exists.
