# generate-word-pages.lua

The word cloud's per-word pages: for each word, the poems closest to it in
meaning, one page per word under `wordcloud/<word>.html`. Two stages, run by
`run.sh`: the word embeddings and word colours (slow, needs the inference
server), then the pages (fast, from those caches). Design: Issues 8-043,
8-050; the poems are drawn by the shared drawer since Issue 8-058.

## Command line

`luajit src/generate-word-pages.lua [--dir PATH] (--embeddings-only | --html-only) --words N|--all --poems-per-page N --chrono-per-page N --threads N --model NAME --server NAME [--yes]`

`--threads` is how many page workers draw the pages (`run.sh` passes the
build's one thread count).

A value not given is asked for, config.lua's default offered; with nobody at
the keyboard it is an error. The settings are read when the file is loaded,
so a script that `require`s it sets `arg` first (`scripts/render-page-sample`
does).

## Functions

| function | takes | returns |
| --- | --- | --- |
| `generate_word_embeddings(options)` | `{}` | the number of words embedded; writes `word_embeddings.json` and `word_colors.json` in the model's folder |
| `generate_word_html(options)` | `{ output_dir = path }` (default `DIR/output`) | the number of pages written, or `nil` when poems or embeddings are missing. Plans every page here and has the page workers draw them (`word-page.lua`). Stops with an error when poem colours, a word's colour, a word's vector or a page's centre poem is missing |
| `generate_word_pages(options)` | as above | both stages |
| `ordered_keys(t)` | a table | its keys in a fixed order: numbers (and number-like strings) by value, then words |
| `more_similar_first(a, b)` | two candidates `{ poem, word_similarity }` | the ranking order: higher similarity first, a tie by lower poem number |
| `spread_colors_across_page(ranked, poem_colors)` | the chosen poems in ranked order, poem number → `{ color }` | the same poems, reordered so the colours alternate down the page |

## How a page is planned

Every poem vector is centred on the poem average once per run, and each word
on the word average once (`embedding-space.centre_once`); a word's score
against a poem is then one dot product (`cosine_centred`), the same number
to the last bit as re-centring for every comparison. The top poems by score
are reordered to spread their colours; the page links to the poem nearest
the centre of its poems.

## One page

A heading in the word's colour, a link to the chronological page holding the
poem nearest the centre of the page's poems, then each poem: its
` -> file:` line and its entry from `poem-entry` (bar by place on the writing
timeline, text, pictures, navigation boxes).

## Same input, same page

Every walk whose order can change a page goes through `ordered_keys`, and
every sort breaks ties by poem number (or colour name). A plain table walk
goes in hash order, which changes between runs; before 2026-10-21 that drew
13 of 60 pages differently on two runs of the same code.

## Tests

`src/generate-word-pages.order.test.lua`; whole pages:
`scripts/render-page-sample --words N --poems-per-word-page M`.
