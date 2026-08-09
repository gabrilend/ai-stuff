# 11-009: Pure-Black Backgrounds Everywhere, for OLED

## Status
- **Phase**: 11 (Advanced Exploration / Presentation)
- **Priority**: Medium
- **Type**: Bug / consistency audit
- **Status**: OPEN — audited, not fixed
- **Created**: 2026-08-08
- **Sorted from**: `new-issue-please-sort`
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

1. Give the source browser the same body attributes the poem pages use. One
   generator, one change; verify with the `grep -L` command above returning 0.
2. Decide whether the palette lives in one place (see Open Questions) and, if so,
   route the generators through it rather than each spelling out its own colours.
3. Re-run the audit across every page family after the next build; the command
   above is the whole test.
4. Check the diagnostic outputs separately, once their intent is settled.

## Relevant Files

- `src/generate-source-browser.lua` — emits the bare `<body>`; the defect
- `src/flat-html-generator.lua` — emits the correct body attributes the rest of
  the site uses
- `src/generate-gallery-pages.lua`, `src/wordcloud-generator.lua`,
  `src/generate-word-pages.lua` — other page emitters, currently correct
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

## Related Issues

- **8-047** — dark mode always on; established the intent this audits against
- **10-052** — built the source browser, the page family that missed it
- **3-006** — no JavaScript; the reason theming is inline attributes and small
  `<style>` blocks rather than a stylesheet with a media query
- **12-002** — dual-axis similarity theme and style; adjacent presentation work
