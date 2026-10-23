# word-page.lua

One word-cloud word's page: the poems closest in meaning to the word, each
drawn by the shared poem drawer. Loaded by the page workers, which draw word
pages beside the similar, different and chronological pages (Issue 10-035).
Which poems, in which order, is decided before, by
`src/generate-word-pages.lua`. `poem-entry.configure` must have been called
in the same Lua state.

## Functions

| function | takes | returns |
| --- | --- | --- |
| `file_name(word)` | the word (string) | its page's file name under `wordcloud/`: lower case, letters and digits only (`"Don't"` → `"dont.html"`) |
| `entry(poem, color_name, progress_pct, chrono_file)` | a poem; its colour name (string); its place on the writing timeline (number 0–100); the chronological page holding it (`"03.html"`) | the poem's ` -> file:` line and its entry, as page text |
| `page_html(word, header_color, centre_link, count, body)` | the word; its colour (`"#rrggbb"`); the link to the poem nearest the page's centre; how many poems; the drawn entries | the whole page |

## The worker job

`flat-html-generator.generate_word_pages_on_workers(jobs, output_dir, num_threads)`
hands each job to the pool as kind `word_page`:

| field | type | meaning |
| --- | --- | --- |
| `word` | string | the word as shown |
| `header_color` | string | `"#rrggbb"` |
| `centre_link` | string | `../chronological/NN.html#<source key>` (Issue 8-019) |
| `entries` | list of `{ poem, progress_pct, chrono_file }` | the page's poems in order, carried in the job (the worker's own poem list has gallery pictures folded in) |

## Tests

`src/word-page.test.lua`
