# 037-the-harness-table.lua

The programs that run a turn. A **row**: `name`, `needs` (programs),
`cost` (`free`, `subscription`), `pool` (default turns at once), `limit`
(seconds), `command(project, turn)` → the program line, and optionally
`serving()` → true, or nil and why: a check beyond the PATH that the
harness can answer now (issue 903b).

Rows: `stand-in` (038, no model); `claude-code` (`claude -p`, restricted
to file tools, reaching only the turn's folders through `--add-dir`, writes
into read-only folders denied by a settings rule, anything that would ask
refused, instructions appended to the system prompt, prompt on standard
input, single JSON result); `ollama` (issue 903, docs/068 — the switchboard's
router; `ollama run <turn.model>` inside 138's single-answer wrapper, prompt
on standard input; refuses a turn with no `turn.model` rather than guess one
— 903c resolves that name, this row only runs it. Needs `ollama`, `luajit`
and `timeout`, and its server answering `ollama list` (903b). The model has
no file tools, so its confinement is the machine's: the wrapper keeps only
what the model prints on standard output and prints it as
`{"answer": ...}`, which the shell line writes to `result.json` (903d)).

| Function | In | Out |
|---|---|---|
| `row(name)` | harness name | the row, after checking its programs are installed and, where it has one, its `serving` check; refuses by name, never handing the turn to another harness |
| `ollama_serving()` | | true when `ollama list` succeeds (the server answers); else nil and what it said, or its exit status |
| `json_string(s)` | a string | the string as a JSON string literal: control characters, quotes and backslashes escaped, other bytes as they came |
| `shell_line(project, row, turn, limit)` | | the full line: go to the working folder, run under `timeout`, output to `result.json`, errors to `stderr.txt`, exit status to `exit` |
| `working_folder(turn)` | turn | the folder holding its first writable path |
| `claude_directories(turn)` | turn | the folders Claude Code may reach besides its working folder — never the whole case, never `turns/` |
| `claude_settings(turn)` | turn | the settings JSON denying edits in read-only folders |
