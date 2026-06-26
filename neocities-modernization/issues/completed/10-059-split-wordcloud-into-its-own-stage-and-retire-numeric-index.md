# 10-059: Give the Word Cloud Its Own Stage; Retire the Orphaned Numeric Index

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Medium
- **Type**: Refactor / Cleanup
- **Status**: Completed (2026-06-26). Verified by dry-run: stage 10 emits the
  wordcloud + word-page commands (seed threaded); stage 9 emits only the poem
  pages, gallery, and source browser; `--help` shows `--generate-wordcloud` and no
  `--generate-index`; `bash -n run.sh` clean. Two LIVE docs still diagram the deleted
  numeric index (`docs/data-flow-architecture.md`, `docs/roadmap.md`) -- a doc-only
  follow-up, no issue required.

## Current Behavior

The pipeline's last two stages are mis-grouped, and the final one is dead:

- **Stage 9 (`--generate-html`, `run_generate_html`)** is a mega-stage doing FIVE
  separate jobs: the poem pages (`main.lua --html-only` -> similar / different /
  chronological), the **word-cloud menu** (`wordcloud-generator.lua`), the **per-word
  similarity pages** (`generate-word-pages.lua`), the image gallery
  (`generate-gallery-pages.lua`), and the source browser
  (`generate-source-browser.lua`). The word-cloud work is bundled in here even though
  it is conceptually a distinct deliverable (the site's entry menu).

- **Stage 10 (`--generate-index`, `run_generate_index`)** runs
  `scripts/generate-numeric-index`, which writes `output/numeric-index.html` (~292 KB
  every build). This output is **orphaned**:
  - Nothing links to it anywhere in the codebase (grep returns no references).
  - Its own header calls it "an HTML fragment for insertion into index.html", but
    `output/index.html` does not exist and nothing generates it. The host page was
    never built.
  - The real, linked index is the **wordcloud's embedded poem index**
    (`generate_poem_index` -> `<h2 id="poem-index">` inside `wordcloud.html`), which
    the source browser links to (`wordcloud.html#poem-index`, Issue 10-055 Feature G).
    The numeric index was superseded by it and never removed.

Net: the menu (the live index) is buried inside the page-generation stage, while the
dedicated final stage regenerates a file no one can reach.

(Adjacent rot, noted not fixed here: `mass-diversity-generator.lua` links to
`../../index.html` as "Poetry Collection" -- the same nonexistent root index. Track
separately if those diversity pages are still generated.)

## Intended Behavior

Regroup so each stage is one coherent deliverable, and drop the dead one:

- **Stage 9 (`--generate-html`)** keeps the page-generation cluster: `main.lua
  --html-only` (similar / different / chronological), the gallery, and the source
  browser.
- **Stage 10 becomes the word-cloud stage (`--generate-wordcloud`,
  `run_generate_wordcloud`)**: the word-cloud menu (`wordcloud-generator.lua`) and the
  per-word similarity pages (`generate-word-pages.lua`). The numeric-index step is
  removed entirely; `scripts/generate-numeric-index` is deleted.

The word cloud already carries the live poem index, so the site's real index ends up
in its own stage and the menu becomes independently rebuildable (regenerate the menu
without redoing ~8,000 poem pages).

### Why this ordering is safe

The word cloud's only cross-stage dependency is the chronological pages: its `#poem`
links must resolve to the chrono page each poem lives on, and those are built by
`main.lua` in stage 9. Stage 10 runs after stage 9, so the chrono pages already exist
-- no new difficulty. The source browser's `wordcloud.html#poem-index` link is a
view-time href, not a build-time dependency, so building the wordcloud one stage later
does not break it.

## Suggested Implementation Steps

1. **Rename the stage-10 flag** throughout `run.sh`: `--generate-index` ->
   `--generate-wordcloud`, `GENERATE_INDEX` -> `GENERATE_WORDCLOUD`. Touch points:
   the help text and header comment, the default var, the arg-parse case, the numeric
   `--stage 10` map (two spots), the `--full` expansion, the "no stages selected"
   guard, the pre-flight stage-list line, and the dispatch line at the bottom.
2. **Move the word-cloud + word-page work out of `run_generate_html`** (both the
   real invocations and their dry-run lines), along with the word-cloud arg-building
   (`wordcloud_words_arg`, `wordcloud_poems_arg`). `chrono_per_page_arg` is needed by
   both stages, so it is computed in each.
3. **Rewrite `run_generate_index` as `run_generate_wordcloud`**: new stage label
   ("Stage 10/10: Generating word cloud menu and word pages"), runs
   `wordcloud-generator.lua` (with `$RANDOM_SEED_ARG`, Issue 10-058) then
   `generate-word-pages.lua`.
4. **Update the TUI interactive menu**: the stage-10 item label/description/flag and
   its force-toggle id (`generate_index` -> `generate_wordcloud`,
   `force_generate_index` -> `force_generate_wordcloud`, the dependency wiring, and
   the value reads in the run-builder).
5. **Update the timing key**: `timed_stage generate-index` -> `timed_stage wordcloud`
   (the `.stage-timings [generate-index]` section is left to age out; it is
   hardware-local and gitignored).
6. **Delete the dead generator and artifact**: `git rm scripts/generate-numeric-index`
   and remove the stale `output/numeric-index.html` (gitignored build output).
7. **Verify**: `bash -n run.sh`; `./run.sh --help` shows `--generate-wordcloud` and no
   `--generate-index`; `./run.sh --generate-wordcloud --dry-run` lists the wordcloud +
   word-page commands (and `--seed=` still threads through); `./run.sh --generate-html
   --dry-run` no longer lists the wordcloud/word-page commands.

## Related Documents / Tools
- `run.sh` -- `run_generate_html`, `run_generate_index` (-> `run_generate_wordcloud`),
  arg parsing, the `--full`/`--stage` maps, the TUI menu, the pre-flight list, dispatch.
- `src/wordcloud-generator.lua`, `src/generate-word-pages.lua` -- moved into stage 10.
- `src/generate-gallery-pages.lua`, `src/generate-source-browser.lua` -- stay in stage 9.
- `scripts/generate-numeric-index` -- deleted.
- Issue 10-055 (source browser; the `wordcloud.html#poem-index` link), Issue 10-058
  (seed threading into the wordcloud), Issue 10-051 (stage timing keys).
