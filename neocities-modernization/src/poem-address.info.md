# poem-address.lua

Where a poem lives on the site, every address named by its source key
(`fediverse-2339`: the source and that source's counting number), never by
its number, which is counted fresh on every extraction (Issue 8-019). One
module owns every address, so no page drifts from the others. Loaded by the
main program and every page worker.

## Functions

| function | takes | returns |
| --- | --- | --- |
| `key(poem)` | a poem | its source key; an error when it has none (a poem list made before keys: rerun the extraction) |
| `anchor(poem)` | a poem | its anchor id on the chronological pages (the key) |
| `page_file(poem, n)` | a poem, a page number | `"fediverse-2339-01.html"`, inside `similar/` or `different/` |
| `text_file(poem)` | a poem | `"fediverse-2339.txt"` |
| `list_link(poem, page_type)` | a poem, `"similar"` or `"different"` | a link, from a page one folder down, to page 1 of that list |
| `chrono_href(poem, chrono_file)` | a poem, its chronological page (`"03.html"`) | `"../chronological/03.html#fediverse-2339"` |
| `chrono_link(poem, chrono_file)` | as above | the same as a link reading "chronological" |

## Why keys

A key moves only when an earlier item of its own source leaves, which the
owner accepted. An old link whose poem has moved to the next chronological
page finds no anchor on the old page, and the browser shows that page's top:
the owner's rule for a poem that is no longer where a link expects it.

## Tests

`src/ranked-page.test.lua`, `src/word-page.test.lua`,
`src/flat-html-generator.chronological-pages.test.lua`.
