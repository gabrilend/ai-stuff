# ranked-page.lua

A poem's similar and different pages, and their text exports. The page
workers and the tests call it (Issue 8-058).

## Functions

| function | takes | returns |
| --- | --- | --- |
| `source_path(poem)` | a poem | how it is named on a ranked page: `"notes/<file name>"`, `"bluesky#<id>"`, `"<category>/<id>"` |
| `ranked_list(ranking, anchor_index, poem_by_index)` | a cached ranking (list of poem numbers), the anchor's number, a table poem number → poem | the ranking as `{ poem, rank }` entries without the anchor; an unknown number is an error |
| `plan(list, pages, poems_per_page, max_pages)` | the ranked list, the requested pages (`{1, 2, 3}` or `"all"`), page size, the storage cap for `"all"` | `(page_numbers, count, total_pages)`: pages to write, poems they hold, pages that hold at least one poem |
| `page_html(anchor, list, page_type, page_num, total_pages, download, ctx)` | the anchor poem, the ranked list, `"similar"` or `"different"`, the page number, the list's page count, `false` or `{ file, count }`, the context | the page's HTML, or `nil` past the end of the list |
| `text_export(anchor, list, page_type, count, ctx)` | as above, and how many poems the export holds | the plain-text export |

## ctx

| field | type | meaning |
| --- | --- | --- |
| `colors` | table, poem number → `{ color = name }` | poem_colors.json |
| `chrono_map` | table, poem number → `{ page_number, total_pages, timeline_progress }` | where each poem sits on the chronological pages and the writing timeline |
| `chrono_paged` | boolean | the chronological view is in numbered pages |
| `poems_per_page` | number | poems per similar/different page |
| `head_block` | string | the shared `<head>` lines |

`poem-entry.configure` must have been called in the same Lua state.

## A page

Navigation line (when there is more than one page), `=== ANCHOR POEM ===`,
the anchor, `=== SIMILARITY RANKED ===` (or `DIVERSITY`), then each poem
under `--- #n source ---` (a text + picture post with an `image.png` link),
the navigation line again, and the download line when exports are on.

## Tests

`src/ranked-page.test.lua`
