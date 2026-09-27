# 060-the-case-viewer.lua

A case as one self-contained HTML page (`view.html`): the survey (languages
as bars, what is leaned on), the blueprint's graph by level with each issue
coloured by state (built, described, planned, failed, held) and its text on
click, the requests (pointing at one lights its touched issues and reach),
the center with a slider replaying the ledger, and the ledger itself. The
page runs its own SHA-256 over the ledger and shows its head hash beside
the machine's; its center uses the machine's own numbers, handed over as
data. Light and dark from the system setting.

| Function | In | Out |
|---|---|---|
| `write(case)` | case | the page's path, and the data it holds |
| `json(value)` | a Lua value | JSON text (keys sorted; `</` escaped so no text can close the script) |
