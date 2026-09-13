# 608 — The documentation gets its toys

| | |
| --- | --- |
| Phase | 6 — Watching It Happen |
| Blocked by | 101, 202, 306 |
| Blocks | — |
| Reads | [the views](../docs/010-the-views.md) |
| Open questions | none |

## Current behavior

`./build-documentation` runs the generator in `scripts/017-the-documentation-becomes-html.lua`
(issue 101), which turns every document, issue, companion and test into
cross-linked pages with a filterable contents rail, every issue number a link,
and a status badge on each issue read off its phase tracker. It carries **five
toys** — `sightline`, `timer`, `costs`, `ground`, and `lockstep` — that a
document places with a line `<!-- toy: name -->`, and it fails the build when a
document asks for a toy that does not exist or links to a page that does not.

Every one of those toys illustrates a **rule** and is driven by sliders the
reader sets. None reads a catalogue table, because none exists yet: the unit
catalogue (issue 202) and the cost table (issue 306) are the assets this issue
waits on.

## Intended behavior

The documentation should let a reader poke at the actual numbers the game runs
on, drawn from the catalogue tables and never typed into a page. When a number
in a catalogue changes, the next build changes the chart; a document never goes
stale by quoting a figure, because it never quotes one.

**A catalogue is read by the generator and embedded as data.** The generator
gains one loader: given a catalogue's stem, it finds the numbered table under
`assets/` by listing, loads it with the same reader the simulation uses, and
writes its rows into the page as a data block the page's script reads. The Lua
table is the source; the page holds a copy made at build time; nothing is
hand-kept. A marker naming a catalogue toy whose table is absent **fails the
build** — this issue adds the markers to the documents only once the tables
exist, so there is no state in which a page shows a toy with nothing behind it.

The toys this issue adds, each a marker and a row in the generator's toy table:

| Toy | Reads | Shows |
| --- | --- | --- |
| `hits` | the unit catalogue | every kind's health as a bar measured in tank shells, with the enforcer's shield stacked on top |
| `heal` | the unit catalogue | a timeline with one row per kind, its heal counter's firings as marks, and a slider for how many seconds of match to show |
| `falloff` | the unit catalogue | each weapon's damage-against-distance curve, on one chart, with a slider that moves a distance marker across all of them |
| `costs` (replaced) | the cost table | the existing shape toy, now drawing the catalogue's actual mass and energy per kind beside the ratio it should have — and marking any row where the two disagree |
| `sight` | the unit catalogue | each kind's eye and profile height as two marks on one scale, which is the whole reason the enforcer is dangerous |

Every chart is drawn as inline SVG by a small script in the page, in the site's
own palette, sized to its container. Charts share one axis style, one legend
style, and one way of naming a kind, so that the pages read as one system.

**The census becomes a picture.** The validator already counts how many issues
have a test naming them; the roadmap page draws that count per phase as a bar,
computed by the generator from the `covers:` lines in `tests/` the same way the
validator computes it, so the roadmap shows how much of itself is specified.

## Suggested implementation steps

1. Add `load_catalogue(root, stem)` to the generator: list `assets/`, find the
   one numbered file with that stem, load it, and return its rows. Zero or two
   matches is an error naming the stem.
2. Add a data-embedding helper that serialises a table of rows — integers,
   doubles, strings, and nothing else — into a script block the page reads.
   Anything else in a catalogue is an error, because a catalogue holding
   anything else is a catalogue bug.
3. Add the five rows to the toy table, each a function of the loaded rows
   returning HTML and script. Extend the marker to carry a catalogue stem, so a
   toy row can say which table it wants and the loader can fail by name.
4. Replace the `costs` toy's sliders-only body with one that draws the table's
   rows and flags any row whose mass-to-energy disagrees with its alignment's
   ratio — the same check the phase 3 test makes, drawn.
5. Draw the census on the roadmap page from the `covers:` lines.
6. Place the markers: `hits`, `heal`, `sight` in the unit document; `falloff` in
   the same; `costs` in the economy document. Rebuild, and fail if any marker's
   table is missing.
7. The test in `tests/024-watching-it-happen.lua` grows a check that the built
   site's unit page contains the embedded rows for every kind in the catalogue,
   by building into the RAM tier and reading the page back.

## Related documents and tools

- [The views](../docs/010-the-views.md) — the documentation as a view of the
  Markdown, and the catalogue as the only place a number lives.
- [The shape of the code](../docs/013-the-shape-of-the-code.md) — balance
  numbers do not live in prose.
- [The generator's companion](../scripts/017-the-documentation-becomes-html.info.md)
  — the toy table and the marker mechanism this issue extends.
- Issue 101 (the generator), issue 202 (the unit catalogue), issue 306 (the cost
  table), issue 205 (the falloff curves the `falloff` toy draws), issue 113 (the
  census the roadmap chart draws).
- `./build-documentation`, `tests/024-watching-it-happen.lua`.

## Still open

- Whether the charts should be drawn once at build time as static SVG, with the
  sliders the only script, or drawn by script from the embedded rows. Script
  from rows is the working choice, because a slider that redraws needs the rows
  anyway.
- Whether the embedded rows should include the balance ledger's history, so a
  chart could show how a number moved over time. The ledger is prose today; if
  it ever becomes a table, this is where that would pay off.
