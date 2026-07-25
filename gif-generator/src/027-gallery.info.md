# 027-gallery — the viewing side

A generator: run it (`luajit src/027-gallery.lua [project-dir]`) and
the whole docs/HTML/ tree is rebuilt from sources — never edit an
HTML page by hand; regeneration is the truth and would erase it.
Reads docs, notes, issues open and completed, and the gifs and
reports in output/ and the phase demos. Its only contact with the
pipeline is reading artifacts; it could run on a machine that never
rendered.

Every page carries the full navigation pane (everything reaches
everything); every issue number mentioned in prose links to that
issue's page (frontier-matched, code blocks skipped); the gallery
index shows each gif looping on black with measured captions from
its report, a palette-occupancy meter, and a glow slider. The
aesthetic is the project's own: black, ember headings, violet links.

## Usable surface

- **build(dir) → pages_built, gif_count**
- **markdown(text, linkify_or_nil) → html** — the honest subset:
  headings, fenced code, lists, paragraphs, bold, emphasis, inline
  code, links. Nothing here parses the whole world.

docs/HTML/ ships with the repository (programs here do not execute
directory commands); the generator says so if it is missing.
