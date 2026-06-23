# generate-source-browser.info.md

Turns this project's tracked code, issues, and docs into a small static website
under `output/source/` — a link-only way to share the source without a public
GitHub repo (GitHub has no "visible only with the link" tier for repositories).
The private monorepo never leaves the machine; whoever has the site link can
browse the published files. It is, in spirit, a "git push that builds a webpage."

This is a standalone script, not a `require`d module — run it; it writes files.

## How to run

- `luajit src/generate-source-browser.lua [DIR]` — `DIR` defaults to the
  hard-coded project root, overridable as the first argument. Also runs as the
  final step of `run.sh`'s HTML stage.

## What it publishes (and what it deliberately does not)

- Source of truth for "which files" is `git ls-files` (so `.gitignore` is
  obeyed — caches, embeddings, and `tmp/` are never listed).
- On top of that it applies an **allowlist** of top-level directories
  (`src`, `libs`, `scripts`, `issues`, `docs`, `notes`, `demos`) plus root-level
  code/doc files. The private `input/` corpus (your messages and unposted poems)
  and `llm-transcripts/` are **held back by default** and the exclusion is logged.
  Widen `INCLUDE_DIRS` in the script to publish more.
- Code files render as syntax-highlighted, line-numbered pages (line numbers are
  `#L<n>` anchors for deep links). **Markdown** files (`.md`, `.info.md`, and
  extensionless prose like the vision doc) render as formatted HTML via
  `libs/markdown.lua` — headings, tables, lists, code, links. Images render
  inline. Genuine binaries are counted and skipped (logged).
- Files are classified in a first pass and the tree is built from only the files
  that actually get a page, so the table of contents can never link a page that
  was not written (this fixed the extensionless-file 404, e.g. `notes/vision`).

## Output

- `output/source/index.html` — welcome + the full collapsible file tree.
- `output/source/<path>.html` — one page per published file, each with the same
  collapsible tree sidebar (the dirs on the path to the current file are opened),
  so every file is reachable from every other.

## Highlighting

A small, dependency-free, line-oriented tokenizer (no JavaScript). Languages are
a dispatch table keyed by extension (`LANGS`): Lua, C/H, and shell get comment /
string / number / keyword coloring with cross-line block-comment tracking; other
text types render plain with line numbers. It is intentionally approximate (no
full grammar) — readable, not a compiler.

## Code folds (Issue 10-055)

The project brackets every function with vimfold markers (`-- {{{ name` …
`-- }}}`). Those markers are turned into clickable `<details>` blocks — collapse
and expand a region with the mouse, with **no JavaScript** (the same mechanism
the sidebar tree uses). Folds default open so the page reads straight through and
deep links to a line still resolve; a marker is only honored inside a comment, so
braces in code are never mistaken for folds; unbalanced markers are closed
defensively so the HTML cannot break.

## Navigation (Issue 10-055)

- **Back to the site**: every page links to the live poetry menu
  (`/similar-different/wordcloud.html`).
- **Issue links**: comments that mention "Issue 10-036" link to that issue's
  page. The number → page map is built from the issues actually published (so it
  finds them whether active or completed); an unknown number stays plain text.
- **The output directory**: rather than list the tens of thousands of generated
  pages, a single `output/` entry deep-links to the live site's poem index
  (`#poem-index`), from which every page is reachable.

## Mirrored saved webpages (Issue 10-055, Feature F)

A saved webpage — an `.html` with a sibling `<name>_files/` directory — is
**mirrored** rather than shown as source: the page itself is written out (so it
renders as the real article) and its CSS/image assets are copied beside it. Every
`<script>` is stripped (the platform is no-JS, and one script is an analytics
tracker a static mirror must not run); interactive bits degrade, the article
reads fine. The table-of-contents entry links to the page itself, not a source
view.

## Known limitations / deferred (see Issues 10-052, 10-055)

- The dash-aligned, description-bearing table of contents (linking each entry to
  its `.info.md`, with a "view source" button) is the remaining 10-055 feature.
- Non-image binaries are skipped rather than linked (the raw bytes are not
  copied into `output/source/`).
- The sidebar embeds the whole tree on every page; fine at the current scale.

## Related

- `issues/10-052-self-hosted-source-browser.md` — design, rationale, and the
  full explanation of why GitHub cannot do link-only repos.
- `src/flat-html-generator.lua` — `generate_explore_page` links here.
