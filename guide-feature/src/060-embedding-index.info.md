# 060-embedding-index — info

The embedding index's own rules and files (issue 502,
`docs/embedding-index-contract.md`): `pieces-v1`, `names-v1`, and
`.embedding-index/`'s `meta`, `pieces` and `vectors`. It calls no model and
needs nothing but LuaJIT's FFI, so another project can copy it in to build
its own index (`docs/embedding-index-build-guide.md`). The builder (061),
the checker (062) and the look tool (503) use it.

| Function | Meaning |
|---|---|
| `names(text, language)` | `names-v1`: the names in code, comments and strings left out; `language` is `lua`, `hash` (shell, Python) or `c` (C, JavaScript) |
| `query_names(text)` | the same rule for a query, with nothing left out |
| `language_of(path, first_line)` | by extension, else by a `#!` line; nil for what is not code |
| `code_only(text, language)` | the text with comments, strings and a `#!` line turned to spaces, newlines kept |
| `split_identifier(id)` | `canvasWidth`, `canvas_width` -> `canvas`, `width` |
| `pieces(text, language, most)` | `pieces-v1`: `{ first, last, kind }` |
| `cut(text, language, most)` | the pieces with their `names`, nameless ones left out |
| `write(folder, meta, pieces, vectors)` | writes the index; vectors made length 1; `meta` last |
| `read(folder)` | `{ meta, pieces, vectors (float*), count, dimensions }`, or nil and why |
| `check(folder, { commit, lines_of })` | the index and a list of problems (what the look tool refuses) |
| `meta_text(meta)`, `read_meta(text)`, `normalise(vector)` | the pieces of the above |

Constants: `RULE` (`names-v1`), `CUT` (`pieces-v1`), `FOLDER`
(`.embedding-index`), `KEYWORDS`, `LANGUAGES`, `EXTENSIONS`.
