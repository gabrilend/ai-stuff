# 11-009: Pure-Black Backgrounds Everywhere, for OLED

## Status
- **Phase**: 11 (Advanced Exploration / Presentation)
- **Priority**: Medium
- **Type**: Bug / consistency audit
- **Status**: IMPLEMENTED 2026-11-02 — the source browser renders on pure
  black and every page generator takes its body colours from one place; the
  look on a phone after the next full build (step 6) is still to do
- **Created**: 2026-08-08
- **Sorted from**: `new-issue-please-sort`; extended 2026-09-22 from
  `next-issue-please-sort` (item 5)
- **Builds on**: 8-047 (dark mode always on), which established the intent

## Summary

On an OLED display a pure-black pixel is an *unlit* pixel. Anything above
`#000000` — even `#0f1117`, which looks black on an LCD — is a pixel drawing
power and emitting light. The site is meant to be read on those screens, so the
background should be `#000000` and nothing else.

The site is mostly already right. The audit below found one page family that is
wrong, and it is wrong in the worst possible way: it sets no background at all,
so it renders in the browser default, which is white.

## Current Behavior

Measured 2026-08-08 against the build then in `output/`. Reproduce with:

```
find output/<dir> -maxdepth 1 -name '*.html' -print0 \
  | xargs -0 grep -L 'bgcolor="#000000"' | wc -l
```

| Page family | Pages | Missing a black background |
|---|---|---|
| `output/chronological/` | 1,151 | 0 |
| `output/similar/` | 8,050 | 0 |
| `output/different/` | 8,050 | 0 |
| `output/gallery/` | 7 | 0 |
| `output/` (explore, menu) | 3 | 0 |
| **`output/source/`** | **9** | **9** |

The 17,000+ poem pages carry
`<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">` and set
no competing background in their `<style>` block. They are correct.

**The source browser is the defect.** Its pages open with a bare `<body>` — no
`bgcolor`, no CSS background — so a browser renders them at its default, white.
Following a link from a pure-black poem page into the source browser is a
full-brightness flash.

### A second, separate finding: the theme variables are not black

`src/model-comparison.lua` defines a CSS custom-property palette used by the
model-evaluation report:

| Variable | Value |
|---|---|
| `--bg` | `#0f1117` |
| `--ink` | `#0b0c10` |
| `--ink-2` | `#13151f` |
| `--card` | `#181b24` |
| `--rule` | `#24262f` |

None is `#000000`. `#0f1117` is a very dark blue-grey — indistinguishable from
black on an LCD, visibly lit on an OLED. This reaches
`output/model-evaluation/comparison-report.html`.

`src/report-generator.lua` is further out: it emits `background: white`,
`background: #f7fafc`, `background: #fef5e7`, and a light-blue
`linear-gradient(135deg, #f0f8ff, #e6f3ff)`.

Both are **diagnostic outputs, not the published site** — which is why they were
never caught. Whether they should match the site's palette is a judgement call
(see Open Questions), not obviously a bug.

### Second report: two panel colours (2026-09-22)

The owner's words, verbatim:

> also there seems to be two different background panel colors?

Re-audit of what is on disk now:

- Pure black (`bgcolor="#000000"`, no competing CSS background): the word-cloud
  menu, the explore page, the gallery, the word pages, both poem-page templates
  in `src/flat-html-generator.lua`, and the chronological redirect page. (The
  poem pages themselves were not on disk to re-measure; their templates were
  read instead.)
- **Not pure black: only the source browser** (`output/source/`). Its pages
  still open with a bare `<body>`, and its stylesheet paints near-black panels
  (`--ink` `#0b0c10`, side panels `#13151f` / `#0e1018`) with gradients. Moving
  from a poem page into it shows a second, slightly lit "black".
- No second background colour was found on the poem pages.

Two explanations fit, and the open question below tells them apart:

1. The owner saw the source browser's near-black panels next to the pure-black
   poem pages — the defect this issue already records.
2. A **mobile browser's automatic dark mode** re-coloured the page. Several
   phone browsers repaint pages they judge to be "light" or unstyled, darkening
   some regions and not others. The pages do not currently tell the browser
   they are already dark, so the browser is free to guess.

## Intended Behavior

Every page a reader can reach from the site renders on `#000000`.

The source browser is published — Issue 10-052 built it precisely so that
"whoever has the site link can browse the source" — so it counts as reader-facing
and must match.

Beyond the immediate fix: **the background is currently decided independently by
each generator**, which is why one of them could drift without anyone noticing
until someone looked at a screen. A single shared definition would make the next
new page type correct by default rather than correct by remembering.

## Suggested Implementation Steps

1. **Done 2026-11-02.** Give the source browser the same body attributes the poem pages use. One
   generator, one change; verify with the `grep -L` command above returning 0.
2. **Done 2026-11-02.** Decide whether the palette lives in one place (see Open Questions) and, if so,
   route the generators through it rather than each spelling out its own colours.
3. Re-run the audit across every page family after the next build; the command
   above is the whole test.
4. **Settled 2026-11-02: left as they are** (see Open Question 2). Check the diagnostic outputs separately, once their intent is settled.
5. **Done 2026-09-22** (tested by `src/page-head.test.lua`; the source
   browser got it with step 1 on 2026-11-02). Declare the pages dark in the shared page head (`src/page-head.lua`): a
   `color-scheme` meta tag saying "dark", and the matching `color-scheme`
   property in its base style. That tells phone browsers the page is already
   dark, so their automatic dark mode leaves it alone. Every page that uses the
   shared head gets it at once; the source browser gets it as part of step 1.
6. After the next build, look at a poem page and a source-browser page on a
   phone (or Firefox's responsive mode) and confirm one background colour.

## Relevant Files

- `src/generate-source-browser.lua` — emits the bare `<body>`; the defect
- `src/flat-html-generator.lua` — emits the correct body attributes the rest of
  the site uses
- `src/generate-gallery-pages.lua`, `src/wordcloud-generator.lua`,
  `src/generate-word-pages.lua` — other page emitters, currently correct
- `src/page-head.lua` — the shared page head; where the dark declaration goes
- `src/model-comparison.lua` — the `#0f1117` palette
- `src/report-generator.lua` — the light backgrounds
- `config.lua` — has no colour-theme section today; a candidate home if the
  palette is centralised

## Open Questions

1. **Should the palette be centralised?** Every generator currently spells out
   its own colours. Putting them in `config.lua` would make drift impossible and
   the OLED intent explicit — but it is a wider change than fixing the one broken
   page, and it touches generators that are currently correct.
2. **Do the diagnostic pages count?** The model-evaluation report and the
   validation reports are tools, not the site. Bringing them to `#000000` is
   consistency; leaving them light is arguably better for reading a data table
   in daylight. They are not linked from the site.
3. **Is `text="#FFFFFF"` right beside pure black?** Maximum contrast is not
   automatically the most readable — pure white on pure black is what people
   mean by eye strain in a dark room. Slightly-off-white text on pure-black
   background keeps the OLED benefit (the background pixels stay unlit) while
   softening the glyphs. That is a taste call, and it is yours.
4. **Are the four `link`/`vlink` colours OLED-appropriate?** `#6699FF` and
   `#9966FF` are mid-brightness on a black field; they were chosen for the
   look, not measured for it.
5. **Answered: which two background colours, and where?** Owner (2026-09-22):
   "don't remember." Treated as unknown. Steps 1–3 (the source browser) and
   step 5 (declaring the pages dark so phone browsers do not repaint them) cover
   both likely causes. The whole-output validator (9-006) should also report
   every background colour each page declares, so a second colour anywhere is
   found by the tool and not by memory.

## Related Issues

- **8-047** — dark mode always on; established the intent this audits against
- **10-052** — built the source browser, the page family that missed it
- **3-006** — no JavaScript; the reason theming is inline attributes and small
  `<style>` blocks rather than a stylesheet with a media query
- **12-002** — dual-axis similarity theme and style; adjacent presentation work

## What Happened (2026-11-02)

Steps 1, 2 and 5 are built; step 4 is settled by leaving the diagnostic pages
alone; steps 3 and 6 need a full build and a phone, which this machine has
neither of.

**One place for the colours.** `config.lua` already had an `html_theme`
section (background, text, link, vlink) that only the gallery read. It is now
the one source: `src/page-head.lua` gained `body_tag(theme)`, which builds
`<body bgcolor=… text=… link=… vlink=…>` from it. It refuses a missing theme, a
missing colour, or anything that is not `#RRGGBB` -- an error at build time
rather than a page in the browser's default colours, and a guarantee that the
tag holds no `%`, so it can be spliced into the `string.format` templates as
it stands. Every page generator on the published site now calls it:

- `src/flat-html-generator.lua` -- all seven poem, chronological, redirect and
  explore templates (a `BODY_TAG` built once at load, beside `PAGE_HEAD_BLOCK`)
- `src/wordcloud-generator.lua` -- the menu page
- `src/generate-word-pages.lua` -- the word pages
- `src/generate-gallery-pages.lua` -- its own hand-rolled copy of the theme
  (with silent `or "#000000"` fallbacks) is gone; it also now carries the
  shared viewport and `color-scheme` tags, which it lacked
- `src/generate-source-browser.lua` -- the defect itself

The poem pages' HTML is byte-for-byte what it was: the shipped theme is the
same four colours that were hard-coded.

**The source browser.** Its `<body>` now carries the theme, its head carries
the shared viewport + `color-scheme: dark` tags, and its stylesheet's three
near-black panel colours (`--ink #0b0c10`, `--ink-2 #13151f`,
`--panel #0e1018`) are all the theme background, written into `_style.css`
when it is generated. The warm glow (two radial gradients over the body), the
grain overlay (an SVG noise layer at 4% over everything) and the sidebar's
gradient are gone -- each lit pixels over the black. Panels and code blocks
are told apart by their rule lines, which were already drawn. The text,
gold, blue and teal colours are untouched.

**Not touched:** `src/centroid-html-generator.lua` (not called by the
pipeline; it hard-codes the same black body and is already right), and the
two diagnostic reports (Open Question 2).

### Decisions on the open questions

1. **Centralise the palette: yes**, in `config.html_theme`, which already
   existed for exactly this and was documented as such. The wider change was
   mechanical (one literal replaced by one call per template) and keeps the
   next new page type correct by default -- the reason the issue gave.
2. **Diagnostic pages: left as they are.** They are tools, not linked from
   the site, and a light table is easier to read in daylight. Routing them
   through `body_tag` later is a one-line change each if wanted.
3. **`text="#FFFFFF"`: unchanged.** A taste call for the owner; it is now one
   value in `config.lua` (`html_theme.text`) to soften site-wide.
4. **Link colours: unchanged**, for the same reason (`html_theme.link`,
   `html_theme.vlink`).
5. The validator reporting every page's background colours belongs to 9-006
   and is not built here.

### Tests

- `src/page-head.test.lua` -- seven new checks: the tag's exact form, refusal
  of a missing theme / missing colour / non-hex colour / a `%`, and that the
  shipped `config.lua` theme builds a pure-black tag. 13 passed.
- `src/generate-source-browser.background.test.lua` (new) -- builds the source
  browser the way run.sh does and runs the issue's own audit: every one of the
  551 pages sets `bgcolor="#000000"` (was: none), every generated page declares
  itself dark, and the stylesheet's panels are `#000000` with no glow, grain or
  old near-black left. 15 passed; 11 of them fail against the old generator.
- The seven `src/flat-html-generator.*.test.lua` suites still pass, and the
  gallery builds from a small fixture catalog with all its pages on black.

### Still to do

- Step 3: after the next full build, run the audit across every page family.
- Step 6: look at a poem page and a source-browser page on a phone.

