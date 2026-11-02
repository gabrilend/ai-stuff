# libs/table-of-contents.lua

Knows which documents a project keeps under `docs/` and which of them its
`docs/table-of-contents.md` links to. Reads only; `update-toc` is the tool
over it that writes.

Load with `dofile(SCRIPTS_DIR .. "/libs/table-of-contents.lua")`.

## Functions

**check(project_dir, ignore)** → result
- `toc_exists` (boolean)
- `docs`: every document, as from `scan_docs`
- `unlisted`: the documents no link in the table reaches
- `dead`: `{ target, line }` for each link that reaches no file

**check_text(project_dir, content, ignore)** → result
The same, against a table given as text. `toc_exists` is not set.

**scan_docs(project_dir, ignore)** → list of `{ rel, title }`
Every `.md` under `docs/` (`rel` from the project root, e.g.
`docs/formats/mpq.md`; `title` the first `# ` heading or nil), sorted by
path. Leaves out the table itself, hidden files and folders, broken symbolic
links, and paths matching any Lua pattern in `ignore`.

**links_in(content)** → list of `{ target, line }`
Every link a markdown text makes outside code, anchors and titles removed,
web and mail addresses left out.

**title_of(content)** → string or nil
**normalize(path)** → path with `.` and `..` collapsed

**unfiled_block(unlisted)** → string
The marked block listing those documents; `""` for an empty list.

**with_unfiled_block(content, block)** → string
The table with its block replaced (or appended, or removed when `block` is
`""`). Raises when the markers do not pair.

**tree(project_name, docs)** → string
A whole table for a project that has none.

## Constants

`toc_rel` (`"docs/table-of-contents.md"`), `START_MARKER`, `END_MARKER`.
