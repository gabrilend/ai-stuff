# 090-switchboard-settings.lua

The switchboard's own settings record (docs/068; docs/010 open question
12). Holds `router_model` (string or nil), the name 903c will read once
the owner has chosen which local model runs on the router. Does not pick
one, and does not refuse a missing one — it only builds the slot.

| Function | In | Out |
|---|---|---|
| `path(project)` | project paths (013) | `<project.dir>/switchboard-settings.lua` |
| `read(project)` | project paths | the settings record; `{}` (so `.router_model` is `nil`) when no file has been written yet |
| `write(project, fields)` | project paths; a table (e.g. `{router_model = "llama3.2"}`) | writes the record (014's neighbour-file-and-rename writer) |
| `resolve_model(project, record)` | project paths; a case record (018) | the model to run: the case's own `<folder>/router-model` file (one line) if present, else `read(project).router_model`; refuses, naming both places checked, when neither names one |
