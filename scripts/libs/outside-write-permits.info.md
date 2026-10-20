# outside-write-permits.lua

Keeps the permissions a person gives for writes outside a session's folder:
requests the write gate files when it refuses, one-time grants (a Yes), and
the allowed list (an Always). Used by `harness-hooks/refuse-outside-writes`
and `harness-hooks/answer-outside-write` (issue 043, step 9).

Storage, outside every project folder so the gate refuses agents writing it:
requests in `/dev/shm/claude-outside-writes/requests/<id>.json`, grants in
`/dev/shm/claude-outside-writes/grants/<session>/<id>.json` (both 30
minutes), the allowed list in `~/.claude/outside-write-allowed-folders`.
`OUTSIDE_WRITE_STATE` and `OUTSIDE_WRITE_ALLOWED` move them, for tests only.

## Data

**request**

| field | type | meaning |
| --- | --- | --- |
| `id` | string | 8 hex digits |
| `session_id` | string | the session the gate refused |
| `places` | list of strings | the refused places, as real places |
| `question` | table | the exact question to ask: `question` (string, ends with `[outside-write <id>]`), `header` (string), `multiSelect` (false), `options` (list of `{ label, description }`: Yes, Always, No) |
| `made` | number | seconds since 1970 |

**grant**: `{ places = list of strings, made = number }`.

**allowed list**: text, one absolute real folder per line.

## Functions

| function | takes | gives |
| --- | --- | --- |
| `file_request(json, session_id, places)` | dkjson, string, list of strings | a **request** (written), or nil and a message |
| `read_request(json, id)` | dkjson, string | the **request**, or nil when none or expired (removed) |
| `close_request(id)` | string | removes it |
| `question_for(id, places)` | string, list | the question table a request holds |
| `grant_once(json, session_id, id, places)` | | true, or nil and a message |
| `spend_grant(json, session_id, places)` | | true when one of the session's grants covered every place, and is now removed |
| `folders_for(places)` | list of strings | the folders an Always adds: a folder stands for itself, a file for its folder |
| `allow_always(places)` | list of strings | adds those folders (unless already covered); true, or nil and a message |
| `allowed_folders()` | | list of strings |
| `is_allowed(place)` | string | true when inside an allowed folder |
