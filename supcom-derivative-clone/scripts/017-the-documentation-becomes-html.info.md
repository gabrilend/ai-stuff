# 017-the-documentation-becomes-html

Every document, issue, companion and test, turned into pages you can browse.

## Running it

```
./build-documentation
```

Writes the pages into `docs/HTML/`. Open `index.html`. The wrapper makes the
output directory; this file only ever reads listings and writes pages.

## What it is for

This project is read far more than it is run. There are more words in it than
code, the words came first, and reconstructing the software means reading them.
But they reference each other constantly, and a directory of files is a bad way
to follow a reference.

So: every page reachable from every other, a contents rail down the side that
can be filtered, **every issue number a link**, and the ideas the design rests on
drawn as things you can push on — a sightline over dunes you can drag, a timer
pair you can advance, a cost table you can slide, a lockstep timeline whose
stall you can cause.

## The same separation, one level up

**The Markdown is the data and the HTML is a view of it**, generated rather
than maintained. Do not edit the output.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `build(root)` | the project root, a string | pages written (integer), the output directory (string); raises with every unresolved reference if there were any |
| `render(markdown, links, report, page_name)` | a document's text; the link tables; a list to append errors to; the page's name for those errors | HTML for one document, a string |
| `PALETTE`, `STYLE` | *(strings)* | the stylesheet, in the game's own colours |

Run with `--dir <root>` it is a program; loaded without it, a module.

## A deliberately incomplete Markdown

Headings, ordered and unordered lists with indented continuation lines, tables,
quotes, fenced code with Lua and shell highlighting, rules, and the inline
marks. Nothing else. A complete Markdown parser is a large thing with many
decisions in it, and every one of those decisions is a way for a generated page
to differ from what the author meant. What is here is what every document in
this project actually uses.

## The cross-reference pass

- `[label](path.md)` becomes a link to the generated page for `path`, and the
  run **fails** if there is no such page.
- `issue 102`, `issues 102, 103`, and a table cell that is exactly an issue
  number become links to the issue, open or completed.
- A code span naming a source file's stem — `the-dunes`, `020-the-dunes.lua` —
  becomes a link to that file's companion page, when one exists.
- A line `<!-- toy: name -->` in a document is replaced by the named interactive
  piece. The toys are `sightline`, `timer`, `costs`, `ground`, and `lockstep`;
  asking for one that does not exist fails the run.

## Badges

An issue page wears its status from the phase progress table as a badge on its
heading, so the page and the tracker cannot disagree.

## Data structures it owns

- `links` — three tables: `page` (slug → slug, every page that exists), `issue`
  (number → slug), `stem` (source stem → companion slug). Built from directory
  listings before any page is rendered.
- `sections` — the rail's groups, each a directory and a filename pattern. Adding
  a directory to the site is adding a row.
- `TOYS` — name → HTML-and-script string. Adding a toy is adding a key.
