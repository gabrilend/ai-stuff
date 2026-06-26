# 10-063: Source Browser — Open Archived HTML Pages Rendered, Not as Source

## Status
- **Phase**: 10 (Developer Tooling / Pipeline Infrastructure)
- **Priority**: Low
- **Type**: Feature
- **Status**: Implemented (2026-06-26) — verified by syntax + classification tests
  (archive/*.html → "view"; other HTML still "code"). Validate the copied page + the
  open-in-new-tab link by regenerating the source browser:
  `luajit src/generate-source-browser.lua <DIR>` and clicking an archived cloud.
- **Builds on**: 10-052/10-055 (the source browser and its Feature F saved-page
  out-links), and the change that added `archive/` to the published allowlist.

## Current Behavior

`archive/` is now published in the source browser, so its dated word-cloud snapshots
(and the `first-published-wordcloud.html` keepsake) appear in the tree. But they are
HTML files, and `classify_file` treats HTML as "code", so clicking one shows its
literal HTML SOURCE (numbered, syntax-highlighted) rather than the rendered word
cloud. For a visual artifact like a word cloud, the source text is the wrong thing to
show -- the reader wants to SEE the cloud.

## Intended Behavior

An archived HTML page is published as a VIEWABLE page: its sidebar entry links
straight to the actual `.html` (opened in a new tab), so clicking it opens the
rendered word cloud. As the request put it: "an external link that happens to link to
an internal page." No source-view page is generated for these files.

This mirrors Feature F (saved pages link OUT to their real article) but points at an
internal copy of our OWN page instead of an external URL.

Scope: HTML files under `archive/` (the word-cloud snapshots). Other HTML elsewhere
in the published tree still renders as source code, as before.

## Design Notes

- **Why copy the raw file.** Only `output/source/` is uploaded, so the archived
  `.html` must be copied there (byte-for-byte, like images are) for the link to
  resolve on the deployed site. The existing `copy_raw()` already does this.
- **Why a new tab + rel=noopener.** It reads as "leaving" the source view to view a
  page, matching the saved-page out-link affordance; rel=noopener is the safe default.
- **Known limitation.** A word-cloud snapshot's internal word links
  (`wordcloud/<word>.html`, `../explore.html`, ...) are relative to `output/` root and
  will not resolve from `output/source/archive/...`. The snapshot's VALUE is the
  visual record of the cloud at that date; the broken click-through links inside it
  are acceptable for an archive. (If full navigability is ever wanted, the snapshot
  would need its links rewritten on copy -- out of scope here.)

## Suggested Implementation Steps

1. Add `is_viewable_html(rel)` (true for `archive/...*.html`) near `classify_file`.
2. `classify_file`: return a new kind `"view"` for those files (before the html ->
   "code" rule).
3. Render loop (pass 2): for `kind == "view"`, `copy_raw` the file into
   `output/source/<rel>` and write no source-view page (like the `"mirror"` branch,
   but it copies the file).
4. `render_sidebar`: for a viewable-HTML file, emit a direct link to `<link_prefix><rel>`
   (no `.html` suffix) with `target="_blank" rel="noopener"`, instead of the
   `<rel>.html` source-view link.

## Related Documents / Tools
- `src/generate-source-browser.lua` -- `classify_file`, `render_sidebar`, the render
  loop, `copy_raw`.
- Issue 10-055 (Feature F saved-page out-links -- the pattern this mirrors).
