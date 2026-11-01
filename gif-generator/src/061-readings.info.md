# 061-readings — three readings of one sentence, and the pick

One sentence goes to the porch (`032-porch.lua`) several times, each
reading faces the wall on its own, each that passes is filmed small,
and a page shows them side by side for the person to pick (issue 602).
A reading that didn't pass is kept and shown dimmed, with the wall's
words or the door that didn't answer.

A folder of readings (the CLI uses `output/readings/SLUG/`) holds
`prose.txt`, and for each reading K: `reading-K.said` (its door, seed,
and the heard lines or the wall's words), `reading-K.lua` and
`reading-K.gif` when it passed, `reading-K.draft.lua` when it didn't,
and `index.html`, the pick page. Every file arrives by rename from a
dot-partial.

## Usable surface

- **plan(doors, count) → { { door, seed }, ... }** — one reading per
  door while doors last, then round again with the next seed. Pure.
- **slug(prose) → name** — the sentence's words, dashed, at most 48
  characters, never empty.
- **one(dir, prose, transport) → result** — `{ ok, text, compiled,
  heard }` or `{ ok = false, errors, draft }`. Never an error: a door
  that fails is a reading that says so.
- **thumbnail(compiled) → bytes, size** — filmed through
  `026-render-main`, every Nth pixel when wider than `THUMB_MOST`
  (128). The score is never changed.
- **land(folder, k, result, door_name, seed)** — one reading's files.
- **read_said(folder, k) → { door, seed, passed, size, heard, wall }**
- **page(folder, prose, count, slug) → path** — the pick page: HTML and
  CSS only, in the gallery's look (`027-gallery.lua`).
- **pick(dir, folder, k, name) → path** — reading K's score into
  `input/NAME.lua`, whole or not at all, never over an existing score;
  appends who heard it to `input/porch-history.txt`.
