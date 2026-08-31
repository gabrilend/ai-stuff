# 150-the-house-style — info

What the documentation site looks like: the page around the words, the colours, and the small drawings made out of the project's own numbers.

`149` decides which pages exist and how they point at each other. This decides what they look like when they arrive -- one page shape used by all two hundred of them, one set of colours, and charts drawn from counts rather than from anything typed in.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `150-the-house-style.lua` and run the sweep again.*

## Invocation

```lua
local house = dofile(DIR .. "/src/150-the-house-style.lua")
local page = house.shell({ title = "...", body = "...", sidebar = "..." })
```

## What it offers

| | What it is |
|---|---|
| `M.stylesheet()` | One stylesheet for the whole site. |
| `M.script()` | The three things on this site that move: the filter over the list of everything, the light setting, and the sliders on the coverage page. |
| `M.shell(page)` | The page around the words. Takes a table: |
| `M.stacked_bars(rows, options)` | One bar per row, each split into coloured parts. |
| `M.ranked_bars(rows, options)` | One bar per row against a single scale, for comparing sizes -- how long each document is, how much each holds. |

### In more detail

**`M.stylesheet()`**

One stylesheet for the whole site. Dark by default with a light setting kept
in the browser, because these are long documents and both kinds of reader
exist.

The look is meant to sit with the subject: a fixed-width face for anything the
machine would say -- headings, code, references, numbers -- and an ordinary
reading face for the prose, which is what most of these files are.

**`M.script()`**

The three things on this site that move: the filter over the list of
everything, the light setting, and the sliders on the coverage page.

Written out rather than fetched. There is no network here by design -- the
site has to open from a file on a disk -- and a documentation site that needs
something downloaded before it renders is a documentation site that stops
working the first time somebody reads it on a machine with nothing on it,
which is a situation this project is unusually likely to be in.

**`M.shell(page)`**

```
The page around the words. Takes a table:

  title     what it is called
  crumb     the line above the title saying what kind of thing it is
  body      the rendered document
  sidebar   the list of everything, already rendered
  outline   the headings of this page, already rendered, or nil
  ledger    what points here and where it came from, or nil
  wide      true for the front page, which is not a column of prose
```

**`M.stacked_bars(rows, options)`**

One bar per row, each split into coloured parts. Rows are
{ label = "phase 1", parts = { { value = 8, colour = "...", name = "..." } } }.

Drawn as plain shapes with the numbers written on them, because a bar you
cannot read the value off is a decoration. The widths are worked out here
rather than by the browser so that the drawing is the same everywhere.

**`M.ranked_bars(rows, options)`**

One bar per row against a single scale, for comparing sizes -- how long each
document is, how much each holds. Rows are { label, value, colour, href }.

## Why the appearance is a separate file

The two halves fail differently. A mistake in the site builder is a broken link or a missing page; a mistake here is something ugly. Keeping them apart means the colours can be changed without touching anything that knows what a ticket is, and it means this file can be read by somebody who only wants to change how it looks.

## The charts are drawn, not charted

They are plain shapes written directly into the page, with no library and nothing fetched -- the site has to work from a file on a disk with nothing running and no network, the same way everything else this project builds has to work with nothing underneath it.

## The numbers in them are counted at build time

Nothing here holds a statistic. A figure that was true when somebody typed it is the failure this project's documentation rules exist to prevent, so every number on the front page comes from counting the files during the build that drew it.

## Where it sits

**Checked by** `151-test-the-documentation-site`.

