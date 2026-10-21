# outside-write-permits.lua

Keeps the permissions a person gives for writes outside a session's folder:
requests the write gate files when it refuses, one-time grants (Once),
This-session permissions, and Always permissions, which belong to one
project (the session's own folder, as a real place) and never to every
session. Used by `harness-hooks/refuse-outside-writes`,
`harness-hooks/answer-outside-write` and
`harness-hooks/forget-session-permits` (issue 043, steps 9-11).

Storage, outside every project folder so the gate refuses agents writing it:
requests in `/dev/shm/claude-outside-writes/requests/<id>.json`, grants in
`/dev/shm/claude-outside-writes/grants/<session>/<id>.json` (both 30
minutes), each session's This-session permissions in
`/dev/shm/claude-outside-writes/session-allowed/<session>` (until the session
ends), Always permissions in `~/.claude/outside-write-allowed-folders`.
`OUTSIDE_WRITE_STATE` and `OUTSIDE_WRITE_ALLOWED` move them, for tests only.

## Data

**request**

| field | type | meaning |
| --- | --- | --- |
| `id` | string | 8 hex digits |
| `session_id` | string | the session the gate refused |
| `project` | string | that session's folder, as a real place |
| `places` | list of strings | the refused places, as real places |
| `questions` | list of 2 tables | the exact questions to ask, each `question` (string, carrying `[outside-write <id>]` or `[outside-write <id> width]`), `header` (string), `multiSelect` (false), `options` (list of `{ label, description }`): How long (Once, This session, Always, No) and How wide (This file, This folder) |
| `made` | number | seconds since 1970 |

**grant**: `{ places = list of strings, made = number }`.

**session list** lines: `<file|folder>\t<place>`. **Always list** lines:
`<project>\t<file|folder>\t<place>`. A `file` line covers exactly its place;
a `folder` line covers it and everything below. Anything else covers
nothing.

**entry**: `{ kind = "file"|"folder", place = string }`.

## Constants

`ONCE`, `SESSION`, `ALWAYS`, `NO` (how-long labels), `FILE`, `FOLDER`
(how-wide labels), all strings.

## Functions

| function | takes | gives |
| --- | --- | --- |
| `file_request(json, session_id, project, places)` | dkjson, string, string, list of strings | a **request** (written), or nil and a message |
| `read_request(json, id)` | dkjson, string | the **request**, or nil when none or expired (removed) |
| `close_request(id)` | string | removes it |
| `questions_for(id, project, places)` | string, string, list | the two questions a request holds |
| `grant_once(json, session_id, id, places)` | | true, or nil and a message |
| `spend_grant(json, session_id, places)` | | true when one of the session's grants covered every place, and is now removed |
| `folders_for(places)` | list of strings | the folders This folder opens: a folder stands for itself, a file for its folder |
| `entries_for(width, places)` | FILE or FOLDER, list | the **entries** an answer adds |
| `allow_for_session(session_id, width, places)` | | adds entries to the session's list; true, or nil and a message |
| `allow_for_project(project, width, places)` | | adds entries to the Always list for that project; true, or nil and a message |
| `session_entries(session_id)` / `project_entries(project)` | string | list of **entries** |
| `is_allowed(place, session_id, project)` | strings | true when an entry of the project's or the session's covers it |
| `forget_session(session_id)` | string | removes the session's list and unspent grants |
