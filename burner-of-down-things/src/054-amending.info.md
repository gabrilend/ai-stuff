# 054-amending.lua

Writes a request into the blueprint, with a way back.

| Function | In | Out |
|---|---|---|
| `amend(project, case, request, touched, options)` | paths table; case; request file name; touched ids; pool options | `{ ok = true, new_ids, attempts }` or `{ ok = false, findings }`. Keeps a copy of the outline and every issue in the turn's `before/` folder; after the turn checks the outline (401's checks), every changed or new issue (403's checks and the house validator), and that every outline row has its file. A failed attempt puts the blueprint back before the next; three failures leave it byte-identical to before. New issues get `described`. A breach puts the blueprint back and raises an error |
