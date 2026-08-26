# 033-the-documentation-site — info

Every document, ticket and companion page in this project, as one cross-linked site.

For a general: the writing here is markdown files that refer to each other constantly -- this document, that ticket, that source file -- and following one of those references currently means opening a file by hand. This turns the whole lot into pages where every reference is a link.

Built rather than written, and not committed. Every page here is derived from a file already in this repository, so tracking the output would put the same words in the record twice and make one documentation edit look like fifty.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `033-the-documentation-site.lua` and
run the sweep again.*

## Invocation

```
luajit src/033-the-documentation-site.lua [--dir ROOT] [--no-figures]
```

## What it offers

| | |
|---|---|
| `M.cross_link(text, known)` | Every reference in a line of prose, turned into a link. |
| `M.to_html(markdown, known)` | One document, as the body of a page. |
| `M.figures(settings)` | The one thing on this site that is not a document: a dial you can turn. |
| `M.build(options)` | The whole site. |

### `M.cross_link(text, known)`

Every reference in a line of prose, turned into a link.

Found by pattern, on the naming conventions this project already follows: a bare three-digit number is a ticket, `docs/NNN` is a document, and a `src/NNN-name.lua` is a source file. The linking is a consequence of the naming rather than a new obligation on anybody writing.

Only references to things that exist become links. A reference to a ticket nobody has written yet stays as text, which is more honest than a link that goes nowhere.

### `M.to_html(markdown, known)`

One document, as the body of a page.

Handles what this project's writing actually uses. A line shape it does not recognise is counted and reported rather than passed through as prose, because a converter that silently drops a construct produces a page that is quietly missing a paragraph and nobody finds out.

### `M.figures(settings)`

The one thing on this site that is not a document: a dial you can turn.

The blur radius is the most important number in the project (`docs/003`) and the paragraph explaining it is worse than seeing it. One character is rendered at a spread of radii and a slider moves between them, so the two failures either side of the right answer -- a black bar drawn on the sky, and nothing in particular anywhere -- can be looked at rather than described.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `escape(text)` |  |
| `highlight(code)` | Lua source with its keywords, strings, numbers and comments marked. |
| `inline(text, known)` | The marks that happen inside a line: code, emphasis, links. |
| `gather(known)` | Every file the site will hold, and the name its page gets. |
| `contents(known, here)` | The column that is always there. |
| `main(argv)` |  |
