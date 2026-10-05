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

1. **A thread count in config.lua?** `main.lua --html-only` now asks for the
   thread count when it is not given, with no default, because `config.lua`
   has none -- so `--yes` stops and names `--threads`. `run.sh` always passes
   it, so builds are unaffected. Add a `threads` setting to `config.lua` so
   `--yes` can take it, or keep threads always explicit?
2. **The box layout.** `src/flat-html-generator.lua` keeps a table of box
   widths and positions with different names and more entries than
   `config.lua`'s `layout` section, and the two disagree (the code says regular
   poems are 82 characters wide, `config.lua` says 83). Which is right, and
   should every layout number move to `config.lua`? Changing it changes how
   every page draws its boxes.
