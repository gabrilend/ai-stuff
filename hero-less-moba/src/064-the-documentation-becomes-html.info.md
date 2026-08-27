# 064-the-documentation-becomes-html

Every document, issue and companion, turned into pages you can browse.

## Running it

```
./build-documentation
```

Writes 152 pages into `docs/HTML/`. Open `index.html`.

## What it is for

This project is read far more than it is run. There are more words in it than code, the
words came first, and reconstructing the software means reading them — but they
reference each other constantly, and a directory of files is a bad way to follow a
reference.

So: every page reachable from every other, a contents rail down the side that can be
filtered, and **every issue number a link.** That last one matters more than it sounds.
The documents mention issues by number a couple of hundred times, and following one by
hand means knowing the naming convention, guessing the description, and listing a
directory.

## The same separation, one level up

**The Markdown is the data and the HTML is a view of it**, generated rather than
maintained — the same rule the simulation and the viewer follow, applied to the
project's own prose. A hand-kept second copy of anything is a copy that will disagree
with the first.

Do not edit the output.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `build(root, modules)` | | Pages written, and where. |
| `render(markdown, links)` | | HTML for one document. |
| `PALETTE`, `STYLE` | *(strings)* | The stylesheet, in the game's own colours. |

## A deliberately incomplete Markdown

Headings, lists, tables, quotes, fenced code, rules, and the inline marks. Nothing
else.

A complete Markdown parser is a large thing with many decisions in it, and every one of
those decisions is a way for a generated page to differ from what the author meant.
What is here is what every document in this project actually uses, established by
reading them.

Syntax highlighting for Lua is three passes over a line rather than a lexer, for the
same reason: the thing being highlighted is already correct Lua that a real compiler
has read, and this only has to make it easier to look at. A lexer would be a second
parser to keep in step with the language.

## The front page has the only pictures

The map is drawn as SVG **from the map builder**, and the shape of a match is drawn from
the timing table — so neither can go stale. A diagram nobody generates is a diagram that
will be wrong, which is the whole reason this file exists.

## The bug worth knowing about

Lua patterns are bytes. A character class written `[-—]` is a class containing the
three separate bytes of an em-dash, and it will happily match one of them and leave the
other two — producing a file that is no longer valid UTF-8.

Every generated page was corrupt in exactly that way, and the symptom was not an error:
it was `grep` quietly deciding the files were binary and reporting nothing, which read
as "the tables did not render". The fix is to match the em-dash as a whole string, and
the comment at the site says so.
