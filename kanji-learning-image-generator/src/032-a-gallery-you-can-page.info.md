# 032-a-gallery-you-can-page — info

Builds a page you can look at a whole set through.

For a general: a run leaves thousands of folders of pictures and descriptions, and nobody is going to open thousands of folders. This turns one into a page.

It is an instrument, not a convenience. The specification of this entire project is that a person squints at a thumbnail and sees the character (`docs/003`), and nothing in this repository can assert that. So the design follows from the test rather than from taste: the field is shown small, because small is where it has to work; large is one click away, because large is where it has to *fail*; and the reasoning behind every picture is on the page, because when an image is wrong the wrongness is visible in the reasoning before anybody generates anything.

NOTHING IS RECOMPUTED HERE. Everything on the page was read out of what the run wrote down. A gallery that worked things out for itself would be a second implementation of the scene grammar, and the day the two disagreed, the gallery would be lying about the pictures.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `032-a-gallery-you-can-page.lua` and
run the sweep again.*

## Invocation

```
luajit src/032-a-gallery-you-can-page.lua --set DIR [--per-page 150]
```

## What it offers

| | |
|---|---|
| `M.stylesheet()` | The look, shared with the documentation site in `033`. |
| `M.read_set(set_dir)` | Every character a run left behind, as the raw text of its card. |
| `M.summarise(card_text, folder)` | The handful of fields the index needs, pulled straight out of the text. |
| `M.build(set_dir, options)` | The whole gallery for one set. |

### `M.stylesheet()`

The look, shared with the documentation site in `033`.

Paper and ink, a great deal of space, one accent -- which is the yellow the stroke-order arrows are drawn in, so the page and the pictures agree. Written once and used by both, because two stylesheets diverge.

### `M.read_set(set_dir)`

Every character a run left behind, as the raw text of its card.

The card is not parsed here. It is spliced into the page and the browser parses it -- which is why there is no reader for this format anywhere in this project. The one thing that needs to understand a card is a web page, and a web page already understands it.

A folder missing its card is recorded rather than skipped. A gallery that is quietly short of the set it claims to show is worse than one with a gap in it, because the gap is at least visible.

### `M.summarise(card_text, folder)`

The handful of fields the index needs, pulled straight out of the text.

By pattern rather than by parsing, because these are five known fields at the top of a file this project wrote itself, and the alternative is a parser for a format nothing else here reads.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `escape(text)` | Text that will not be read as markup. |
| `page_shell(title, subtitle, body)` |  |
| `main(argv)` |  |

## Where it sits

Used by `033-the-documentation-site`.
