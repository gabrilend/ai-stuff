# 10-071: Defaults Live Only in config.lua, Never in the Code

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Medium
- **Type**: Design rule + cleanup
- **Status**: Open
- **Created**: 2026-10-04
- **Related**: 10-065 (run.sh demands every value), 10-065a (programs ask for
  a missing value; where this rule was first stated and first applied),
  10-060 (dead code -- several sites below are in modules it may retire)

## The owner's rule (2026-10-04)

> the only place we should have "default" values is config.lua. Never in the
> code itself.

## Current Behavior

**Where it stands (2026-10-25).** Steps 1-3 are built; step 4 is done for
every site the checker finds; the two open questions below are the owner's.
- **The checker (step 1):** `scripts/audit-config-fallbacks` lists every
  place a program reads a setting with its own fallback beside it --
  "value" (`x.size or 5`) and "section" (`config.layout or {}`) -- and
  lists apart the fallbacks declared meant by an `optional:` comment with
  the reason, on the line or the line above. Run it for the live inventory;
  the table below is the inventory of 2026-10-04, kept for the record.
- **Moved into config.lua and made required** (a missing one is an error
  naming it): the gallery sources' names, titles and layout; the word
  cloud's settings, its colours now the site's `semantic_colors` (owner,
  2026-10-25); the fediverse extractor's privacy settings (one could never
  be turned off: a `false` fell through to `or true`); the picture
  importer's formats and size limit (its built-in 10 MB contradicted
  config's 200 MB); the gallery theme's colours; the deploy's request
  pacing (`deploy.uploads`, `deploy.deletions`, with the values the code
  used); the GPU walk's tuning (`gpu.diversity`: batch size, probe steps,
  chunk time, safety factor, the card's L2 size and the share of it a tile
  uses; all 9,334 walks came out identical before and after); the two
  libraries kept outside the project (`libraries.tui_lua_dir`,
  `libraries.effil_cpath`); the tests' model and server (`testing`).
- **Made required where the code assumed them:** a server's model list and
  name, the `sources`, `word_cloud` and `image_integration` sections, the
  image source folders, the plain-text column width.
- **Declared optional, with the reason:** stop words (none beyond the
  short-word rule), excluded pictures and poems (none excluded), a source's
  excluded subfolders, a server's extra launch flags and its description, a
  model's vision projector (a text-only model has none), the page builder's
  per-section read (so every missing setting is named in one error), and a
  call option in the kept `url-manager.lua`.
- **Retired with the modules:** `similarity-calculator`,
  `report-generator` and `validation-engine` and their settings (10-060).

Before (2026-10-04):


Much of the code reads a setting with a fallback written beside it:
`config.section.setting or 5`. When `config.lua` has the setting, the number
in the code is dead weight that will quietly disagree with `config.lua` the
day someone edits one and not the other. When `config.lua` lacks it, the
number in the code wins silently, and nobody can see from `config.lua` what
the program is doing.

Already brought under the rule (10-065a, 2026-10-04): the page builder's page
and storage settings (`src/flat-html-generator.lua` holds no numbers of its
own; a missing setting is an error naming it), the word cloud's word count,
the word pages' word count and page size, and the chronological page size in
both word programs.

Remaining, found by searching for "setting or literal" expressions outside
comments (41 lines, re-run the search to refresh -- see step 1):

| Where | Settings with a fallback in the code |
|---|---|
| `src/wordcloud-generator.lua` | `min_occurrences or 5`, `font_size_min or 1`, `font_size_max or 7`, `min_word_length or 3`, `output_file or "wordcloud.html"` (all in `config.lua` already), and the colours (below) |
| `scripts/extract-fediverse.lua` | privacy `mode or "clean"`, `anonymization_prefix or "user-"`, `local_server_domain or "tech.lgbt"` (the owner's home instance written into the code) |
| `src/image-manager.lua` | `supported_formats` (a list of image types), `max_file_size_mb or 10` (twice) |
| `src/similarity-calculator.lua` | `default_algorithm or "cosine"` |
| `src/flat-html-generator.lua` | `layout.text_content_width or 80` at one site, `pages_list or { 1 }`, a page count `or 1`; and the whole box-layout table (see open question 2) |
| `src/report-generator.lua`, `src/validation-engine.lua` | report `format or "html"`, `max_discrepancy_samples or 20`, `tolerance or 0.001` (the validation suite; 10-060 decides whether it stays) |
| many files | `config.section or {}` -- an absent section treated as empty. Each is either a real "this section is optional" or a silent default; to be decided per site |

**A bug found by the same search:** `src/wordcloud-generator.lua` reads its
colours from `config.colors`, a section `config.lua` does not have (the
colours live in `semantic_colors`). So the word cloud always uses the colour
values written in its own code, and editing `config.lua` changes nothing.

## Intended Behavior

- A setting is read from `config.lua` and nowhere else. No program writes a
  fallback value beside it.
- A required setting missing from `config.lua` is an error naming it (all
  missing ones at once where practical, as the page builder does).
- A section that is genuinely optional says so in a comment where it is read,
  with the reason.
- When a program is run on its own and a per-run value is missing, it asks
  (10-065a); the default it offers comes from `config.lua`.

## Suggested Implementation Steps

1. A checker that lists every "setting or literal" expression outside comments
   (the search used above, made into a script beside `scripts/audit-config-keys`),
   so this inventory can be re-run instead of trusted.
2. Fix the word-cloud colour bug: read `semantic_colors` (or name the right
   section), with a test that a colour edited in `config.lua` reaches the page.
3. Remove each code fallback whose setting is already in `config.lua`; for each
   whose setting is not, add the setting to `config.lua` with the code's
   current value and a comment, then remove the fallback.
4. Decide each `or {}` site (optional section, or required).
5. Regenerate `docs/config-reference.md`; run `scripts/audit-config-keys`.

## Open Questions

1. **Answered (owner, 2026-10-25): "always explicit."** No `threads`
   setting in config.lua; the thread count is always given (`--threads`, which
   run.sh always passes), and a program run on its own asks for it.
   The question, as asked: **A thread count in config.lua?** `main.lua --html-only` now asks for the
   thread count when it is not given, with no default, because `config.lua`
   has none -- so `--yes` stops and names `--threads`. `run.sh` always passes
   it, so builds are unaffected. Add a `threads` setting to `config.lua` so
   `--yes` can take it, or keep threads always explicit?
2. **Answered (owner, 2026-10-25).** "The maximum amount of text inside a
   poem is 80 characters. It is possible, but rare, for a poem to have a
   trailing space or something, but these should be either stripped out or
   ignored somehow. The left side of the box needs a |, then a space, then
   the poem text, then a space, then a |. That's the constraint." So every
   frame is `text_content_width + 4` = 84 columns, regular and golden alike
   (regular poems were 83, one short); `src/poem-bars.lua` derives every
   column from the text width it is configured with; the page builder's
   own box table and config.lua's other `layout` numbers (which nothing drew
   with, and which disagreed: 83/85 widths, junctions "5" and "6") are gone,
   leaving `layout.text_content_width = 80`; a line's trailing spaces are
   dropped before and after wrapping (`src/poem-entry.lua`); and
   `scripts/validate-output` holds every frame piece to the same width,
   taken from the same setting. The owner chose "Widen regular to 84",
   then: "only the golden poems should be framed. That's what separates them
   from the rest. But, the spacing of the other poems should be such that you
   can't tell, based on their text alignment, whether or not they're regular
   or golden - only the borders will tell you." So regular poems stay
   unwalled, and their text takes a 2-column indent (as wide as "║ "),
   starting in the golden text's column.
   The question, as asked: **The box layout.** `src/flat-html-generator.lua` keeps a table of box
   widths and positions with different names and more entries than
   `config.lua`'s `layout` section, and the two disagree (the code says regular
   poems are 82 characters wide, `config.lua` says 83). Which is right, and
   should every layout number move to `config.lua`? Changing it changes how
   every page draws its boxes.
