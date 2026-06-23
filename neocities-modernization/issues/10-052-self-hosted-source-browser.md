# 10-052: Self-Hosted Source Browser (Link-Only Code Visibility)

## Status
- **Phase**: 10 (Developer Tooling)
- **Priority**: Medium
- **Type**: Feature
- **Status**: Open

## Background / Why This Exists

`neocities-modernization` lives inside a larger PRIVATE monorepo (`ai-stuff`).
The goal is to let people see THIS project's code "only if they have the link" —
hidden from the public, but viewable by anyone the link is shared with.

GitHub cannot do this:
- A repository is either **public** (indexed, discoverable, on your profile) or
  **private** (invited collaborators only). There is no "unlisted/link-only" repo.
- A **secret Gist** is link-only but is a flat file list — it cannot render a
  multi-folder project tree usefully.
- **GitHub Pages** inherits repo visibility; private-repo Pages is paid and
  access-restricted to org members, not link-only-public.
- `git subtree split --prefix=<path> -b export` can peel this folder into its own
  repo, but that repo would have to be PUBLIC to be viewable — fully discoverable,
  the opposite of link-only.

Therefore the only mechanism that delivers true link-only visibility is to
**generate a browsable static site of the source and host it under the neocities
output** that is already shared by link. The monorepo stays private; nothing
goes to GitHub. This also completes a goal the project vision already states:
documentation, issues, and source as interconnected HTML with a table of
contents, where clicking an issue number jumps to that issue.

## Current Behavior

`src/generate-source-browser.lua` builds the browser into `output/source/` and
runs as the final step of `run.sh`'s HTML stage. It lists tracked files via
`git ls-files` (honoring `.gitignore`), applies an allowlist of directories
(`src`, `libs`, `scripts`, `issues`, `docs`, `notes`, `demos`) plus root-level
code/doc files, and renders:
- text files as syntax-highlighted, line-numbered pages (line numbers are
  `#L<n>` anchors), with a small no-JS tokenizer (Lua/C/shell get token colors;
  other text renders plain);
- images inline; other binaries skipped (counted/logged);
- an index page plus, on every page, a collapsible file-tree sidebar with the
  current file's path opened, so every file is reachable from every other.

The private `input/` corpus and `llm-transcripts/` are deliberately NOT published
(allowlist), and every held-back directory is logged. Directory creation is
quoted so paths with spaces (e.g. a saved-webpage folder) publish correctly, and
write failures are surfaced rather than swallowed.

**Deferred (so this issue stays open):**
- Issue-number cross-linking and `.info.md` ↔ source linkification.
- Non-image binaries are skipped rather than linked (raw bytes not copied into
  the output tree).
- A standalone CLI flag / its own `run.sh` mode (currently it always runs inside
  the HTML stage).

Originally the source/issues/docs were viewable only in an editor or via git;
the `.info.md` companions existed as intended building blocks but nothing
assembled them into a navigable, link-shareable site.

## Intended Behavior

A generator that turns the project tree into a static, browsable website:

- **Honors `.gitignore`.** Only non-ignored, tracked files are published (use
  `git ls-files` so the ignore rules are obeyed exactly — never publish secrets,
  caches, embeddings, or `tmp/`). Anything excluded is silently absent, and the
  exclusion list is logged so it is auditable.
- **One HTML page per file**, syntax-highlighted, with line numbers (line numbers
  double as anchors so deep links to a specific line work).
- **A table-of-contents sidebar**: the file tree, every file reachable from every
  other file (the vision's "reach every file from every other file"). Honors the
  project's indexed-filename reading order where present.
- **Issue cross-linking**: an issue reference in any rendered file becomes a link
  to that issue's page; `.info.md` files link to/from the source they describe.
- **Unified style** matching the site aesthetic (black background, monospace,
  the same `FONT_STYLE`), consistent across pages.
- **Output under the neocities output** (e.g. `output/source/`) so it ships with
  the rest of the link-shared site.
- **A `run.sh` step** ("source push" / regenerate) so updating the browsable code
  is one command — the "git push that builds a webpage instead of pushing".

## Design Decisions To Settle Before Building

These shape the implementation and are worth confirming:
- **Syntax highlighting approach**: a small server-side Lua tokenizer (no JS, pure
  static, but must cover Lua/C/bash/markdown), OR a single embedded client-side
  highlighter (e.g. highlight.js) — one JS dependency, broad language coverage,
  but a departure from the no-JS norm. Recommendation: start with a Lua tokenizer
  for the languages actually in the repo; revisit if coverage is painful.
- **Binary / asset files**: render a link/preview (images shown, audio/video
  linked) rather than dumping bytes.
- **Ordering**: by the project's file-index convention where files are indexed,
  else directory/alphabetical.
- **Output path and whether it is regenerated every run or on demand only**
  (it can be large; on-demand via a `run.sh` flag is likely right).

## Suggested Implementation Steps

1. New `src/generate-source-browser.lua` with a hard-coded `${DIR}` and an
   optional argument override (per project script convention).
2. File discovery via `git ls-files` (honors `.gitignore`); classify each file as
   renderable-text vs asset; log anything skipped.
3. Per-file renderer: HTML-escape, highlight, number lines (anchors), wrap in the
   shared page furniture.
4. TOC sidebar builder: the file tree as nested links, present on every page.
5. Issue-number linkifier and `.info.md` ↔ source cross-linker.
6. Integrate: a `src/main.lua` / `run.sh` step ("source") that regenerates the
   browser into `output/source/`.
7. Point the explore page's "Browse the source" link (Issue 11-004) at the index
   of this browser.
8. Add a small validator that confirms every published file is reachable from the
   TOC and that no `.gitignore`d path leaked in.

## Related Documents / Tools

- Project vision (CLAUDE.md): docs/issues/source as interconnected HTML with a
  TOC; issue numbers clickable; reach every file from every other file.
- `src/*.info.md` files — the per-file nodes this browser links together.
- `src/flat-html-generator.lua` — `FONT_STYLE` and the shared page furniture.
- `/issues/11-004-rewrite-explore-page-and-add-deeper-math-page.md` — the page
  that links to this browser.
- `run.sh` — where the "source push" step is added.
