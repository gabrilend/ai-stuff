# 053-endpoint-tools — info

Switch a role's endpoint, and list the endpoints (issue 402). Run on
kuvalu, where the project-root `endpoints` file is (`docs/endpoints.md`).
`scripts/use-endpoint` and `scripts/list-endpoints` call it.

    luajit src/053-endpoint-tools.lua --dir ROOT use ROLE NAME
    luajit src/053-endpoint-tools.lua --dir ROOT list

| Function | Meaning |
|---|---|
| `use(root, role, name)` | points `use.ROLE` at `name` after `check`; returns the old name (or nil) and the new one. Nothing is written when a check fails |
| `check(root, file, role, name)` | the endpoint record if `name` can serve `role` now, else nil and why: in the file, the kind the role needs, a timeout, a usable key file, answers `GET /v1/models` and a token count (which needs the key) |
| `rewrite(text, role, name)` | the file's text with the one `use.ROLE` line's value replaced, its spacing and comment kept, or a line added at the end |
| `list(root)` | every endpoint, by name: `{ name, kind, url, answers, problem, roles }` |
| `format(rows)` | the list as lines for a person |

`use` writes `endpoints.part`, reads it back whole with 001's
`read_endpoints` (`file = "endpoints.part"`), then renames it over
`endpoints`, so a turn never reads half a file. The same choice again
writes nothing. Exit 1 with the reason on any refusal, 2 on wrong words.
