# 148-render-markdown — info

One written document to the HTML of its body. The rendering half of the documentation site; `149` is the half that decides what gets rendered.

The documents in this project are written in the plain-text convention where a line starting with a hash is a heading and a run of pipes is a table. Something has to turn that into what a browser draws. This is that, and it is deliberately small: it handles what these documents actually contain rather than everything the convention allows.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `148-render-markdown.lua` and run the sweep again.*

## Invocation

```lua
local render = dofile(DIR .. "/src/148-render-markdown.lua")
local body, headings = render.markdown("# a heading\n\nand a paragraph")
```

## What it offers

| | What it is |
|---|---|
| `M.markdown(source, link)` | A markdown document to the HTML of its body. |

### In more detail

**`M.markdown(source, link)`**

A markdown document to the HTML of its body. Returns the html and a list of
its headings, each { level, text, id }, which is what builds the outline that
sits beside a long page.

Handles what this project actually writes: fenced code, headings, tables,
bulleted and numbered lists, quotes, rules and paragraphs. It is a renderer
for these documents rather than a general one, and anything it does not know
comes out as a paragraph, which is the harmless failure.

## Why it is separate from the site

Turning text into HTML and deciding which files exist are different jobs with different failure modes -- one produces ugly output and the other produces a broken link -- and keeping them apart means the renderer can be exercised on a string with no directory anywhere near it.

## How cross-referencing gets in without this knowing about it

Every entry point takes a `link` function, which is handed the text inside a code span and answers with a destination or nothing. So this never learns what a ticket is, what a source file is, or which of them a bare number means; it only knows that some code spans turn out to be links.

## What it does not handle, on purpose

Nested emphasis, reference-style links, footnotes, and lists more than two deep. None of them appear in these documents, and anything unrecognised comes out as a paragraph, which is the harmless failure rather than the silent one.

## Where it sits

**Checked by** `151-test-the-documentation-site`.

