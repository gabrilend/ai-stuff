# chronological-page.lua

The frame around the chronological pages, loaded by the page workers that
build them (Issue 8-058). The poems inside come from `poem-entry.lua`.

## Functions

| function | takes | returns |
| --- | --- | --- |
| `navigation(current_page, total_pages)` | numbers, 1-based | "« First │ ‹ Prev │ Page X of Y │ Next › │ Last »" with links where there is somewhere to go; `""` for one page |
| `display_filename(poem)` | a poem | `"notes/<original file name>"` for notes, `"<category>/<id>"` otherwise |
| `entry_header(poem)` | a poem | its anchor (`<span id="<source key>">`, e.g. `fediverse-2339`, Issue 8-019) and the ` -> file: <name>` line, ending in a newline |
| `file_name(page_num, total_pages)` | numbers | `"01.html"`… when there are several pages, `"index.html"` for one |
| `page_html(page_num, total_pages, head_block, body)` | numbers, the shared `<head>` lines (string), the drawn poems (string) | the whole page |
| `redirect_html()` | nothing | `chronological/index.html` for a paginated view: a redirect to `01.html` |

## Tests

`src/flat-html-generator.chronological-pages.test.lua` builds paginated and
single-page views through the workers and checks them.
