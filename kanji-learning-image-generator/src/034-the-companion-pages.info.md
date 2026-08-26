# 034-the-companion-pages — info

Writes the .info.md page that sits beside every source file, out of the comments already in that source file.

For a general: this project's rule is that you read a file's companion page rather than its code, unless you are chasing a specific bug in a specific function. That only works if the page is true, and a page maintained by hand stops being true on the first edit somebody makes in a hurry. So the page is not maintained -- it is regenerated, from the source, every time.

The extraction is possible because every function in this project is wrapped in a fold that names it, and the lines under that fold are its explanation. That convention was already required for editing comfort; this makes it load bearing, which is the cheapest kind of documentation there is.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `034-the-companion-pages.lua` and
run the sweep again.*

## Invocation

```
luajit src/034-the-companion-pages.lua [--dir ROOT] [--check]
```

## What it offers

| | |
|---|---|
| `M.read_source(path)` | One source file, pulled apart into the pieces a page is made of. |
| `M.who_uses(name, all_files)` | Which other source files load this one. |
| `M.render(source, users)` | One source file's description, as the text of its page. |
| `M.sweep(options)` | Every source file's page, written. Returns what was written and what changed. |

### `M.read_source(path)`

One source file, pulled apart into the pieces a page is made of.

Returns a table with:   name       the file's base name, without .lua   heading    the descriptive block at the top, as paragraphs   invocation the command line, if the header showed one   entries    an array of { name, arguments, external, doc }

The header block is everything from the second line to the first line that is not a comment. Its first line is the filename, which is dropped -- the page has a title already and repeating it there would be the same words twice.

A line in the header that looks like a command is pulled out as the invocation, because "how do I run this" is the question a page gets asked most and it should not be buried in a paragraph.

### `M.who_uses(name, all_files)`

Which other source files load this one.

The project loads siblings by name through src/009, so a mention of the file's name in another file is a dependency. Grepping for it is exact enough and needs no import graph.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `source_files()` | Every source file in src/, in index order. |
| `strip_comment(line, marker)` | The text of a comment line, or nil if the line is not one. |
| `first_sentence(doc)` | The opening line of a fold's comment -- what the function is, in one line. |
| `remaining_prose(doc)` | Everything after the first line, as paragraphs. |
| `main(argv)` | Run directly, this sweeps. --check reports what would change and writes |
