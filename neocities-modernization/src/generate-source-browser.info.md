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
- Text files render as syntax-highlighted, line-numbered pages (line numbers are
  `#L<n>` anchors for deep links). Images render inline. Other binaries are
  counted and skipped (logged).

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

## Known limitations / deferred (see Issue 10-052)

- Issue-number cross-linking and `.info.md` ↔ source links are not yet wired.
- Non-image binaries are skipped rather than linked (the raw bytes are not
  copied into `output/source/`).
- The sidebar embeds the whole tree on every page; fine at the current scale.

## Related

- `issues/10-052-self-hosted-source-browser.md` — design, rationale, and the
  full explanation of why GitHub cannot do link-only repos.
- `src/flat-html-generator.lua` — `generate_explore_page` links here.
