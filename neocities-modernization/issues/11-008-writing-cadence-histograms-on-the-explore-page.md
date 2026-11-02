# 11-008: Writing-Cadence Histograms (By Month, By Quarter) on the Explore Page

## Status
- **Phase**: 11 (Advanced Exploration)
- **Priority**: Medium
- **Type**: Feature
- **Status**: IMPLEMENTED 2026-11-02 — built and tested on fixture poems; the
  real corpus's figure is seen on the next full build
- **Created**: 2026-08-08
- **Sorted from**: `new-issue-please-sort`
- **Builds on**: 11-004 (created the explore pages), 11-005 (moved their prose
  into editable templates)

## Summary

The corpus knows when every poem was written but never says so. Two histograms
on the explore page — one bucketed by month, one by quarter — would show the
shape of the writing over time: the stretches of daily output, the quiet months,
whether the pace is rising or falling.

Two resolutions rather than one because they answer different questions. Monthly
shows bursts and gaps; quarterly shows the trend underneath them, which monthly
noise hides.

## Current Behavior

- Every poem carries a date; the chronological pages are ordered by it, and
  `flat-html-generator.lua` already computes a per-poem "timeline progress"
  percentage for the decorative bars (Issue 8-045). So the data and the
  date-to-position arithmetic both exist.
- The explore page (`page-templates/explore.txt`, rendered by
  `src/flat-html-generator.lua`) carries prose only. Nothing on the site shows
  the distribution of writing over time.
- The site is static HTML with JavaScript deliberately removed (Issue 3-006), so
  a charting library is not available and not wanted.

## Intended Behavior

Two histograms on the explore page, generated at build time as part of stage 9:

- **By month** — one bar per calendar month across the corpus range.
- **By quarter** — one bar per quarter, same range.

Each bar labelled with its bucket and count. The pair reads as one figure: same
visual language, stacked, so the eye can move between resolutions.

## Design Notes / Constraints

**No JavaScript.** Issue 3-006 removed it on purpose. Two viable renderings:

1. **Text bars in a monospace block** — `█` repeated proportionally, which is the
   visual language the poem boxes and progress bars already use. Cheapest, and it
   matches the site rather than importing a different aesthetic.
2. **Inline SVG** — sharper, scales, still static and dependency-free. More code,
   and a second visual idiom to keep consistent.

Option 1 is the better fit for this project: `libs/poem-bars.lua` already draws
proportional bar geometry, and reusing it means the histogram looks like it
belongs rather than like a chart pasted on.

**Bucket range and empty buckets.** A month with no poems must render as a
present-but-empty bar, not be skipped — the gaps are part of what the figure
shows, and omitting them would silently compress time.

**Where the counting happens.** The generator has the poems and their dates in
hand during stage 9; no new data source is needed. Whether the counts are
computed inline or written to a small JSON first is worth deciding — a JSON
would make the numbers checkable without reading the HTML, in keeping with the
project preference for a validator over a hardcoded claim.

## Suggested Implementation Steps

1. Decide the rendering (text bars vs inline SVG); the rest follows from it.
2. Count poems per month and per quarter from the same date field the
   chronological ordering uses, preserving empty buckets across the full range.
3. Render both histograms, reusing the existing bar geometry if going with
   text bars.
4. Place them on the explore page. Note that the prose lives in
   `page-templates/explore.txt` while generated content is assembled in
   `src/flat-html-generator.lua` — so the templates may need a placeholder
   marking where the figure is injected, rather than the figure being appended
   wherever the generator happens to end.
5. Check the result against a known count (the corpus total should equal the sum
   of all buckets in each histogram — a cheap invariant worth asserting).

## Relevant Files

- `page-templates/explore.txt` — the explore page prose (Issue 11-005)
- `src/flat-html-generator.lua` — assembles the explore pages; already computes
  timeline positions from poem dates (Issue 8-045)
- `libs/poem-bars.lua` — existing proportional bar geometry
- `assets/poems.json` — the dates

## Open Questions

1. Text bars or inline SVG?
2. What is the actual date range and how many buckets does that make? If the
   corpus spans years, a monthly histogram may be too wide for a page that is
   otherwise 83 characters across. Measure before choosing the layout.
3. Do image-only posts count as writing? They have dates and poem indices but no
   text, and including them would inflate months heavy with photos.
4. Should boosts count, when included? They carry a date but are someone else's
   words.

## Related Issues

- **11-004** — created the explore pages this attaches to
- **11-005** — moved their prose into `page-templates/`
- **3-006** — removed JavaScript; the constraint that shapes the rendering choice
- **8-045** — timeline-based progress bars; the existing date-to-position work
- **10-056** — phase demos computing real statistics; same "show the real
  numbers" instinct, different surface

## What Happened (2026-11-02)

The explore page now carries a **WHEN THEY WERE WRITTEN** figure, under the
source list: poems per quarter (the trend), then poems per month (the bursts
and the quiet stretches), drawn as the same monospace `█`/`·` bars the math
page uses, every bucket labelled with its count.

- **Counting** -- `writing_cadence(poems_data)` in `src/flat-html-generator.lua`
  (exported as `M.writing_cadence`). It reads dates through
  `sort_poems_chronologically_by_dates`, the chronological pages' own sort, and
  turns each timestamp back into a calendar month with `os.date`, so a poem is
  counted in the month it sits under when reading start to finish. It walks
  every month from the first counted poem to the last, so empty months and
  empty quarters are present with a zero.
- **The invariant** -- both histograms must sum to the number of poems counted;
  if either does not, the build stops with the two numbers rather than
  publishing a figure that does not add up.
- **Drawing** -- `cadence_bars()` stacks one `ascii_bar_row` per bucket, each
  histogram scaled to its own largest bucket. `ascii_bar_row` gained an
  optional `show_any`: a non-zero bucket always fills at least one cell, so a
  quiet month (one poem beside a month of two hundred) never looks like an
  empty one. The math page's charts do not pass it and are unchanged.
- **Placement** -- `page-templates/explore.txt` gained the figure's prose with
  markers (`CADENCE_COUNTED`, `CADENCE_FIRST`, `CADENCE_LAST`,
  `CADENCE_IMAGE_ONLY`, `CADENCE_BOOSTS`, `CADENCE_MONTH_COUNT`, and the two
  bar blocks `CADENCE_QUARTERS`, `CADENCE_MONTHS`). The wording is the owner's
  to edit; the loops stay in code (the 11-005 split). Every line of the figure
  carries a marker, so with nothing dated to count (the explore page called
  without a poem list) the whole figure drops out instead of leaving headings.

### Decisions on the open questions

1. **Text bars**, as the issue recommended: the site's own visual language,
   the existing `ascii_bar_row`, no second idiom.
2. **Width vs. range** -- the bars run horizontally, one row per bucket, so a
   long span makes the figure taller, never wider: a row is at most about 60
   characters whatever the range. The real span could not be measured here (no
   poems.json on this machine). At ten years the monthly figure is about 120
   rows; if that reads as too long on the real build, a one-line-per-year
   sparkline of the twelve months is the compact alternative.
3. **Image-only posts are not counted** as writing, and neither are gallery
   images; the page states how many were left out.
4. **Boosts are not counted** (someone else's words); the page states how many.
5. **Counts are computed inline, not written to a JSON first.** The build-time
   sum check is the validator, and nothing else would read the file.

### Tests

`src/flat-html-generator.cadence.test.lua` (new, 28 checks): the month and
quarter counts on a five-month fixture with an empty January; image-only posts
and boosts counted apart; a year-long gap keeping all fourteen months and five
quarters; nothing-to-count cases; and the real `explore.html` built from the
real template (synced into `input/pages/` as run.sh does), checking the
headings, the empty month drawn as dots and a zero, the busiest month full, a
quiet month still visible, and no marker left unfilled. The seven other
`flat-html-generator` suites and `page-template.test.lua` still pass.

