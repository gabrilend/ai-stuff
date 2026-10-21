# poem-entry.lua

The one drawer for a poem's whole entry on a page. Chronological, similar and
different pages all draw through it, so a poem looks the same everywhere.
Design: Issue 8-058.

## Functions

| function | takes | returns |
| --- | --- | --- |
| `configure(opts)` | `opts.palette` (table, colour name → `"#rrggbb"`, must include `gray`), `opts.boost_palette` (table: `arrow`, `outer_frame`, `inner_box`, `content_text`, each `"#rrggbb"`), `opts.text_width` (number, the text column, 80) | nothing; errors if any field is missing |
| `format_entry(poem, entry)` | a poem from poems.json (or a picture-only entry, `is_image = true`) and an **entry** table (below) | the entry as page text, no trailing newline |
| `escape_html(text)` | string | the text with control bytes removed and `& < >` escaped |
| `apply_markdown(text)` | escaped string | `*x*`, `**x**`, `~~x~~` and `` `x` `` styled, the marks kept visible |
| `media_href(path)` | an attachment's relative path (string) | its address under `media/`, url-encoded |
| `to_plain(html)` | an entry's HTML (string) | the same as plain text: pictures as `[Image: …]`, `[Audio: …]`, `[Video: …]` lines, tags removed, entities decoded |
| `utf8_char(cp)` | a Unicode code point (number) | its UTF-8 bytes (string) |

`configure` must be called once in each Lua state (the main program and every
worker thread) before `format_entry`.

### entry

| field | type | meaning |
| --- | --- | --- |
| `color_name` | string | the poem's semantic colour, a key of the palette (`"gray"` when the poem has none) |
| `progress_pct` | number, 0–100 | how far through the writing timeline the poem was written |
| `similar_link` | string | `<a>` to the poem's similar page |
| `different_link` | string | `<a>` to the poem's different page |
| `chrono_link` | string or `false` | `<a>` to its place on the chronological pages; `false` on those pages themselves |
| `plain` | boolean, optional | `true` for a text export (Issue 8-013): no navigation boxes, the plain bottom bar, no HTML |

## What an entry looks like

- **Regular poem:** top bar (with a screen-reader label), the text with a
  1-column indent, pictures, the two navigation boxes, bottom bar.
- **Golden poem** (exactly 1024 characters when posted): the same, with the
  text between a coloured `║` and a `│`, 84 columns wide, and the navigation
  boxes joined to the walls. Pictures come before the boxes, so the frame
  stays in one piece.
- **Boost:** the nested boost frame (`boost-bars`), then pictures.
- **Picture-only entry:** `image-render`'s picture box.

The text: a warning from the post itself is boxed first; then every line that
starts `CW:` or `content warning:` is boxed where it stands, and every other
line wraps at the text column keeping its leading indent. Emphasis is styled
with its marks kept (Issue 4-003).

## Test

`src/poem-entry.test.lua`
