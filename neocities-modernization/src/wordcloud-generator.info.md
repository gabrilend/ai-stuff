# wordcloud-generator.lua

Builds the word-cloud menu page, `wordcloud.html`: the collection's most
used words (stop words left out), sized by how often they appear, in an order
shuffled from one seed (Issue 10-058), each linking to its word page. Run by
`run.sh` stage 10 before the word pages (`src/generate-word-pages.lua`).

## Command line

`luajit src/wordcloud-generator.lua [--dir PATH] [--all | --words N] [--chrono-per-page N] [--seed N] [--model NAME] [--server NAME] [--out FOLDER] [--yes]`

| option | meaning |
| --- | --- |
| `--all`, `--words N` | every word, or the N most used |
| `--chrono-per-page N` | the chronological page size; must match the one the chronological pages were built with, or links land on the wrong page |
| `--seed N` | the shuffle's seed: the same seed gives the same order. Without it a seed is made and logged |
| `--model`, `--server` | the embedding model whose word colours the words are drawn in |
| `--out FOLDER` | a trial run: the page goes into FOLDER, not the site, and no record is kept in `archive/wordclouds/` (that record is for builds, Issue 10-073) |
| `--yes` | take config.lua's value for anything not given |

A value not given is asked for (config.lua's offered); with nobody at the
keyboard it is an error.

## Functions

| function | takes | returns |
| --- | --- | --- |
| `generate_wordcloud(poems_data, output_dir)` | poems.json as loaded; the folder to write into | the written file's path, or nil |
| `main()` | -- | as above, for the command line |

## Tests

`scripts/seed-reproducibility.test.sh` (same seed, same page; another seed,
another order; the seed stamped in the page), run before every build.
