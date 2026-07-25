# 026-render-main — the runner

The program the vision describes: score files from input/, through
read → wall → sim → snapshot → splat → tone-map → index → encode,
landing finished gifs in output/ with an honest report beside each,
goodbye written last. Also the one true pipeline spine as a module —
demos, tests, and the porch's thumbnails share it.

## Usable surface

- **render(compiled) → frames, facts** — the spine. Facts are all
  measured: frames, peak particles, capacity, palette seats lit,
  per-stage CPU seconds (reports only — nothing rendered ever
  depends on a clock).
- **render_to_gif(compiled) → bytes, facts** — spine plus encoder.
- **run(dir, wanted_or_nil)** — the front door: one named scene or
  everything in input/. Finished files arrive by rename from a
  dot-partial in the same directory (cross-filesystem rename fails
  with EXDEV — the reasoning is a comment); failures remove their
  partial, siblings continue, the exit code remembers.

Invoked directly (`luajit src/026-render-main.lua [dir] [scene]`) it
teaches Lua its own library path first; the root `run` script is its
thin wrapper. Reports land as plain data lines beside each gif; the
render log streams to the RAM tier (a missing tier means bootstrap
has not run — said aloud, not worked around).
