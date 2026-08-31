# 147-describe-the-source — info

Reads a source file and writes the info document that belongs beside it.

Every source file in this project is supposed to have a short companion page saying what it offers, so a reader can learn what a file does without reading the code. Most of them did not have one. This makes them -- not by inventing prose, but by lifting the prose the source file already carries in its own comments, which is the only version that cannot drift.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `147-describe-the-source.lua` and run the sweep again.*

## Invocation

```
luajit 147-describe-the-source.lua --all              every file missing one
luajit 147-describe-the-source.lua --all --force      every file, rewritten
luajit 147-describe-the-source.lua --file src/144-assemble-a-machine.lua
luajit 147-describe-the-source.lua --all --dry-run    say what would be made
```

```lua
local describe = dofile(DIR .. "/src/147-describe-the-source.lua")
local page = describe.read("/path/to/018-launch-board.lua")
local text = describe.render(page)
```

## What it offers

| | What it is |
|---|---|
| `M.read(path)` | One source file to a description of it. |
| `M.checked_by(dir, name)` | Which test programs mention this file by name. |
| `M.render(page, checked_by)` | A description to the markdown of its info document. |
| `M.sweep(dir, options)` | Every source file in the project, described. |

### In more detail

**`M.read(path)`**

```
One source file to a description of it. Returns a table:

  name      "144-assemble-a-machine", the filename without .lua
  index     144, the number it sorts by
  kind      "library" if the file ends in `return M`, else "program"
  summary   the header's first paragraph, as one string
  sections  a list of { heading, body } lifted from capitalised paragraphs
  notes     paragraphs that were not headed and not usage, as strings
  usage     command lines from the header's `usage:` block
  exports   a list of { signature, description, inline } from the vimfolds
  issues    issue numbers the header mentions, in order, without repeats

Returns nil and a reason when the file cannot be read or carries no title
line, because a file that does not follow the shape is not one this can
describe and saying so is better than emitting an empty page.
```

**`M.checked_by(dir, name)`**

Which test programs mention this file by name. Derived by looking rather than
by being told, because a list of tests written into a comment is a list that
stops being true the first time somebody adds one.

Returns a list of test file names, without the .lua.

**`M.render(page, checked_by)`**

A description to the markdown of its info document. The shape follows the
pages that were written by hand: what it is, how it is called, what it
offers, then whatever the source had to say about itself.

**`M.sweep(dir, options)`**

Every source file in the project, described. options.force rewrites pages
that already exist; without it, hand-written pages are left alone.
options.dry_run says what would happen and writes nothing.

Returns counts: made, skipped, refused -- and the list of refusals, because
a file this cannot describe is a file worth looking at by hand.

## Why it is a tool and not seventy-eight documents

A page written by hand starts accurate and decays, and nobody notices, because nothing reads it. A page derived from the comments is wrong only when the comments are wrong, and the comments sit where somebody changing the code is already looking. So the way to improve a generated page is to improve the source's header, which is the outcome worth having anyway.

## What it will not do

It will not overwrite a page somebody wrote by hand. Forty-seven of these existed before this file did and they are better than anything derivable -- they say why a thing exists and what it deliberately refuses to know, which is not in any signature. Those are left alone unless --force is passed, and --force is not used by anything that runs unattended.

## What it reads, and the conventions it depends on

This project writes its source files the same way everywhere, and that regularity is the whole reason this is possible:

## Worth knowing

  * a title line, `-- NNN-name.lua`, right after the shebang   * a prose header in comments, ending at the first line of real code   * paragraphs inside that header which OPEN WITH A CAPITALISED PHRASE when     they are making a separate point -- those become the page's sections   * `usage:` inside the header, followed by indented command lines   * exported things wrapped in vimfolds: `-- {{{ M.name(arguments)`, then     comment lines describing it, then the definition   * `return M` at the end of anything meant to be called by another file

If a file breaks those conventions the page comes out thin rather than wrong, and a thin page is a signal about the source rather than a defect here.

