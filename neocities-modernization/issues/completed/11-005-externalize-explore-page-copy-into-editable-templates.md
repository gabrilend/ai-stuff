# 11-005: Externalize the Explore Page Copy into Editable Templates

## Status
- **Phase**: 11 (Advanced Exploration)
- **Priority**: Medium
- **Type**: Enhancement
- **Status**: Open
- **Builds on**: 11-004 (which created the two explore pages)

## Current Behavior

The two explore pages are generated in `src/flat-html-generator.lua` by
`generate_explore_page` (explore.html, the map) and
`generate_explore_math_page` (explore-2.html, the deeper math). Every line of
prose -- the welcome paragraph, the "WAYS TO EXPLORE" descriptions, the whole
math explanation about embeddings / cosine similarity / the word cloud -- is
hard-coded inside those two functions as a long run of `add("...")` calls. Live
numbers (poem counts, date span, per-source / per-year / length histograms) are
computed by `corpus_stats` and interleaved with the prose by the same `add`
calls.

To change a single sentence on either page, a person has to open a 4500-line Lua
source file, find the right `add(...)` line, and edit Lua-quoted strings. The
words and the rendering machinery are tangled together.

## Intended Behavior

The *words* of both explore pages live in plain-text files under `input/` that
anyone can open and edit. The *machinery* (computing the numbers, drawing the
ASCII bar charts, wrapping the page in the site's black-background shell) stays
in Lua. A small substitution step joins them: the editable file carries
`{PLACEHOLDER}` markers, and the generator fills each marker with a live value
just before writing the page.

- `input/pages/explore.txt` -- the full text of explore.html, with markers for
  the live scalar numbers and one marker for the per-source list block.
- `input/pages/explore-math.txt` -- the full text of explore-2.html, with markers
  for the embedding-model name and the three histogram blocks.

### Placeholder system

Reuses the project's existing `{UPPERCASE_NAME}` marker convention (the one
`report-generator.lua` already uses), with two deliberate improvements that
follow the "errors over fallbacks" rule:

1. **Unknown markers are an error, not a silent pass-through.** If a template
   contains a `{MARKER}` the generator has no value for (a typo, a renamed
   field), generation halts with a message naming the offending marker. The old
   `substitute_template_vars` would have left the raw `{MARKER}` text on the
   page.
2. **A value may be `template.OMIT`** to drop the whole line that mentions it.
   This reproduces the current conditional behavior -- e.g. the "spanning X to Y"
   line and the "N image-only posts" line only appear when those facts exist --
   without leaving a blank gap where the line was.

Scalars (counts, dates, the model name) are inline markers. Repeating content
(the source list, and the three histograms, which are loops over the corpus)
stays rendered in Lua and is dropped in as a single block marker each. This is
the agreed split: a person edits all the prose and the scalar wording; the code
keeps the loops.

### Two-way split (data vs. view), unchanged in spirit

`corpus_stats` still computes; the render functions still render. The only change
is that the render functions now read their prose from a file instead of holding
it inline, and pre-build the loop blocks as strings to hand to the substitutor.

## Suggested Implementation Steps

1. Add a small, dependency-free template module (`src/page-template.lua`) with
   a substitute function (string + value table -> filled string, or an error on
   any unresolved marker) and a render-from-file helper. Include the `OMIT`
   sentinel and `%`-safe replacement. Give it an `.info.md` and a `.test.lua`.
2. Write `input/pages/explore.txt` and `input/pages/explore-math.txt` carrying
   the exact current copy with markers substituted in for the live values.
3. Rewrite the two generator functions to: compute `corpus_stats`, pre-render the
   block strings (source list; source / length / year bars), assemble the value
   table (including the embedding-model name from `inference-server-config`,
   so it never goes stale), render the template file, and wrap the result in the
   shared `explore_page_shell`.
4. Resolve the template path from `DIR` (the same project-root constant the rest
   of the file already uses), so the pages can be generated from any directory.
5. Verify byte-for-byte (modulo intentional model-name freshness) that the
   generated explore.html / explore-2.html match the pre-change output for a
   populated corpus, and that an empty corpus still produces a sane page.

## Related Documents / Tools
- `src/flat-html-generator.lua` -- `generate_explore_page`,
  `generate_explore_math_page`, `corpus_stats`, `ascii_bar_row`,
  `explore_page_shell`.
- `src/page-template.lua` (new) -- the substitution engine; see its `.info.md`.
- `src/report-generator.lua` -- the pre-existing `{PLACEHOLDER}` convention this
  generalizes.
- `libs/inference-server-config.lua` -- source of the live embedding-model name.
- `/issues/11-004-rewrite-explore-page-and-add-deeper-math-page.md` -- the issue
  that built the pages this one makes editable.
