# 055-the-documentation-builder

Turns the project's Markdown into one cross-linked, browsable site.

Read this page rather than the source.

## What it is for

Every document, every issue, every companion page and every source file, with a
contents column that reaches all of them from any of them, and three pages that
have something you can move on them.

The pages under `docs/HTML` are a **view**. They are generated, they are
gitignored, and nothing is lost by their absence. Committing them means every
prose edit arrives as a diff of itself plus a hundred files of machine output,
and it means two people who both ran the build have a conflict in something
neither of them wrote.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `build(root)` | project root | the number of pages written |
| `render(markdown, links)` | | HTML |
| `highlight(code)` | Lua source | HTML with spans |
| `slug(path)` | a source path | the output file name |

`build` is what `./build-documentation` calls. The rest are exported so a test
can reach them.

## The Markdown converter is deliberately small

It handles what this project's prose actually uses — headings, paragraphs, lists,
tables, fenced code, block quotes, rules, and the four inline forms — and nothing
else. A general Markdown implementation would be several times the size of the
thing it is formatting.

**Code spans are pulled out first and put back last.** A backtick-quoted file
name must not be turned into a link and an underscore inside a code span must not
become emphasis. Every text formatter that does not do this eventually mangles
something and nobody can say which rule did it.

## The highlighter tokenises rather than substituting

One pass, longest match first, no backtracking. A sequence of substitutions is
the obvious approach and it is wrong in a way that looks fine until it does not:
colouring keywords first and then comments means the keywords *inside* a comment
have already been wrapped in tags, and the comment rule then swallows the tags.

## Every page is flat

Directories are flattened into the file name with a dash, so every page sits
beside every other and a link between any two is just a file name — no relative
paths to get wrong, which is the entire class of bug that `057-the-relinker.lua`
exists to repair in the Markdown.

## Automatic cross-links

Any backticked source file name becomes a link to that file's companion page.
Written once, in the builder, so no document has to carry the link — and so a
file renamed in one place does not leave a hundred dead references behind.

## The three toys

They go on the pages they explain, so a reader meets each one immediately after
the paragraph that describes it.

- **The column explorer**, on the stone document. Click a layer, watch
  `c & ~(c >> 1)` compute, and see the pile redraw. This does more to explain the
  project's central idea than the document does, because three operations are
  nothing to read about and something to watch.
- **The projection playground**, on the projection document. Three constants on
  sliders, and a small maze that redraws. Two-to-one stops being a claim.
- **The numbers**, on the front page. A maze is generated and validated at build
  time, so no figure on that page can go stale.
