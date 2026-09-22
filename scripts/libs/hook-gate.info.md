# hook-gate.lua

What every Claude Code hook in `scripts/` shares: reading the hook input,
spending a one-time permission token, refusing, and announcing a warning.

## How the harness reads a hook (Claude Code 2.1.280)

| hook does | harness does |
| --- | --- |
| exit 0, prints nothing | no objection |
| exit 0, prints `{"hookSpecificOutput": {"permissionDecision": "deny", …}}` | refuses the tool call; the reason goes to the model |
| exit 0, prints `{"systemMessage": "…"}` | shows the message to the person as a warning |
| exit 2 | blocks the tool call (not used here) |
| any other exit | non-blocking error; the tool call runs |

## Functions

| function | takes | gives |
| --- | --- | --- |
| `read_input(name, scripts_dir)` | gate name, scripts directory | the decoded input table and the dkjson module; on any failure, a warning and exit 0 |
| `pending_command(name, input)` | gate name, input | `tool_input.command` (string); a warning and exit 0 if absent |
| `warn_and_allow(name, message)` | gate name, message | prints `systemMessage` and to standard error, exit 0 — the announced fallback |
| `spend_token(path)` | token path | true (was there, now gone), false (absent), or nil and a reason (there but cannot be removed) |
| `refuse(json, reason)` | dkjson, reason | prints the deny decision, exit 0 |
| `refuse_unless_token(json, path, reason)` | dkjson, token path, reason | spends a token and exits 0, or refuses |
| `run(argv)` | list of words | output (standard error folded in) and success boolean |
| `shell_quote(word)` | string | the word quoted for `/bin/sh` |
| `load_json(scripts_dir)` | scripts directory | dkjson from `<scripts>/../libs/lua/dkjson.lua` |
