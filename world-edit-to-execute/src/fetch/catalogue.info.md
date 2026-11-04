# catalogue.lua

The catalogue file of one source (issue 603): `<player data>/catalogue/<source>.lua`,
written by `fetch` and read by the catalogue viewer (1001).

| Function | Takes | Gives |
|----------|-------|-------|
| `write(path, cat)` | a path, `{source, entries}` | writes it (by way of a `.part` file); raises on an entry without a kind (`"map"`/`"model"`) or title |
| `read(path)` | a path | the catalogue, or nil and a message; loaded as text only with an empty environment, so it can't run code |
| `check(entry, i)` | an entry | raises when it lacks kind or title |

Entry fields: `kind`, `title` (required); `author`, `version`, `posted`,
`terms`, `page_url`, `download_url`, `preview_url`, `size_bytes`,
`published_hash`; and, once downloaded, `hash`, `checked`, `stored_as`,
`downloaded`.
