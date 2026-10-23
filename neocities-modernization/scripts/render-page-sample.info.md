# render-page-sample

Draws a sample of the site into a fresh folder, through the same page workers
a build uses, without touching the site: every chronological page, the
similar and different pages of a fixed sample of poems (or the poems named
with `--anchor`), and optionally the first N word pages. Run it before and
after a change to how pages are drawn and compare the two folders
(`diff -r`, and `scripts/validate-output --output FOLDER` for widths and
frames). Design: Issue 8-058, step 7.

## Usage

`scripts/render-page-sample [DIR] --out FOLDER --model NAME --server NAME --threads N --poems-per-page N --pages N|all [--anchor N]... [--copy-pictures] [--words N --poems-per-word-page M]`

| option | meaning |
| --- | --- |
| `--out` | where the pages go; must not exist yet (put it in `tmp/shared-memory/`) |
| `--model`, `--server` | the embedding model whose caches are drawn from, and the server entry naming it (no default) |
| `--threads` | worker threads |
| `--poems-per-page`, `--pages` | similar/different page size and pages per poem, as `run.sh` takes them |
| `--anchor N` | a poem number (its number in this run's poems.json, counted by date), any number of times: only these get similar/different pages. A number no poem has stops the run before anything is drawn |
| `--copy-pictures` | copy the pictures into `FOLDER/media` (about 1.5 GB, so in RAM) instead of linking `assets/site-media`; for before a build has filled that folder |
| `--words N --poems-per-word-page M` | also draw the word pages of the first N words, M poems each (needs the word-cloud stage's caches) |

## The sample

Fixed by rule, no randomness: the first 25 poems (in poems.json order) of
each hard case (golden, boost, post warning, emphasis, pictures, a later
"CW:" line, an 80-wide line), plus every 200th poem.

## Used by

`src/main.lua`'s "Test one poem's pages" (`--anchor`), `demos/5-demo.lua`.
