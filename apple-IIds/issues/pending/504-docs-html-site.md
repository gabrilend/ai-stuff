---
name: documentation site at docs/HTML/
phase: 5
status: pending
blockedBy: []
---

# 504 — documentation site at docs/HTML/

All project documentation (docs/, notes/, issues/, info.md files)
is rendered as a unified HTML site under `docs/HTML/`. Every page
links to every other page; a table of contents lives on the left of
every page; charts, diagrams, and interactive widgets bring the
content to life.

## current behavior

Documentation lives as Markdown files. Reading it requires either
`cat` in a terminal or a Markdown viewer outside the project. No
cross-linking, no diagrams beyond ASCII art.

## intended behavior

- A static site under `docs/HTML/` rendered from the Markdown
  sources by a small builder script.
- Every doc, every note, every issue, every `info.md` file becomes
  an HTML page.
- A left-side TOC reflects the tree from
  `docs/000-table-of-contents.md`, navigable to every page.
- Every cross-reference in the source Markdown (`docs/...`, issue
  numbers like `101`, function/module names) becomes a live link.
- Code blocks have syntax highlighting (65C816, ARM assembly, Lua,
  C, all the languages the project touches).
- Diagrams are rendered (the ASCII layer diagram in arch overview
  becomes a real SVG; the radial keyboard layout becomes an
  interactive SVG you can hover over).
- The aesthetic matches the project's tone: a little of the
  platinum-desktop IIds feel, but readable on modern screens.
- The site is regenerated from source on every documentation
  change. A `make docs` command (or equivalent) does this.

## suggested implementation steps

1. Pick a static-site approach. Candidates:
   - **Pandoc** — converts Markdown to HTML with templates;
     well-known.
   - **A custom Lua script using cmark** — keeps the build in our
     stack (LuaJIT); we control the rendering.
   - **mdBook / Zola / Hugo** — heavy for this purpose.
   The custom Lua approach aligns with the project's "use the
   stack you're already using" preference; pick this unless it
   proves harder than expected.
2. Write the renderer:
   - Walk all .md files under the project.
   - Convert each to HTML.
   - Build the cross-link table by collecting all the headings,
     issue numbers, doc filenames.
   - Replace inline references in each rendered file with
     `<a href="...">` tags.
   - Generate the left-side TOC by walking the docs tree.
3. Add syntax highlighting (highlight.js or similar).
4. Add SVG diagrams for the key ASCII illustrations.
5. Style the site (CSS — IIds-ish but legible).
6. Write `make docs` (or `build-docs.sh`).
7. Test: open the site in a browser, click around, verify every
   link works.

## related documents

- All project documentation — this issue's input
- `docs/000-table-of-contents.md` — drives the navigation

## known design questions

- Hosted vs local? For now, local-only. The site lives in the
  project tree and you open it in a browser. Hosting would require
  the project to be public (which is a separate decision —
  third-party-deployment posture is set but public hosting isn't).
- Auto-refresh during development? A watcher script that rebuilds
  on file changes would be nice for the docs writer. Defer to a
  follow-up.
- Cross-link to source code? Eventually yes — `info.md` files
  link to the functions they document, those functions link to
  their source. But source-code-linking is a phase 9+ concern.

## notes

- The convention "every page links to every other page" is
  aspirational. A practical version: every page has the left-side
  TOC (so it can reach any other), plus inline links wherever a
  cross-reference makes sense, plus a "related" footer with
  hand-curated links from the source Markdown's "related documents"
  sections.
