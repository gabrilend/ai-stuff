# fetch-cloud-conversations

Conversations that run in the cloud (claude.ai/code sessions; Claude Duet
threads, once they can be reached, see below) never write to
`~/.claude/projects` on this computer, so `backup-conversations` has never
seen them. This script downloads each one's log, and the logs of the helper
agents it started, from the cloud into a store of its own and hands every
session that changed to `backup-conversations`, which files it in a project's
`llm-transcripts/` folder the usual way (issue 051).

**Remote Control sessions are passed over.** They show up in the cloud's
listing too, but they ran in Claude Code on this computer: their logs are
already in `~/.claude/projects`, and their transcripts already exist in the
project they ran in. The cloud's copy holds nothing the local log lacks.
`--list` marks each session `cloud` or `remote-control`.

**Duet threads are not reached yet.** They are not in either listing Claude
Code's sign-in can read; finding them is the open step of issue 051.

The cloud keeps a session's log in the same shape Claude Code writes locally,
one JSON object per line, so the parser needs no changes: the script only has
to put the lines in a folder `backup-conversations` can be pointed at.

## Use

```bash
./fetch-cloud-conversations --list                 # date, id, kind and title of each session
./fetch-cloud-conversations                        # fetch everything, export what changed
./fetch-cloud-conversations --limit 20             # only the newest 20 sessions
./fetch-cloud-conversations --session session_01…  # one session
./fetch-cloud-conversations --fetch-only           # download, but write no transcripts
```

The end of each run says how many sessions were new, changed, unchanged and
empty, and how many Remote Control sessions it passed over. An empty log fails
the run and names the session. An unchanged session costs two pages (its log
and its helpers) and is not exported again, so it is cheap to run from cron:

```
*/30 * * * * /mnt/mtwo/programming/ai-stuff/scripts/fetch-cloud-conversations --limit 50
```

## Where things go

- **Fetched logs:** `~/.claude/cloud-projects/<project folder, dashed>/<session id>.jsonl`,
  and each helper's beside it in `<session id>/subagents/agent-<helper>.jsonl`
  with an `agent-<helper>.meta.json` describing it, the layout Claude Code
  uses locally. Claude Code's own store is never written to.
- **Helper descriptions** come from the helper's launch in the parent's log.
  A cloud log starts at its latest compaction, so a helper launched before
  it has no description, and the export stops and names it (issue 051, open
  question 3).
- **Transcripts:** the project's `llm-transcripts/`, through `backup-conversations --session`.
- **Which project:** a session that worked in a repository named in
  `config/cloud-session-projects` (copy the `.example` beside it) goes to that
  repository's project. Every other session, Duet threads included, goes to
  your home folder, whose transcripts already land in `~/ai/llm-transcripts`.

## Sign-in

It reuses Claude Code's sign-in on this computer: the access token in
`~/.claude/.credentials.json` and the organisation in `~/.claude.json`. The
token goes into a header file in RAM that only you can read and that is
removed at the end of the run; it never appears on a command line, in a log
or in a fetched file.

When the token has run out, the script says so and stops. Start `claude` once
(it refreshes the token) and run it again. A 403 means the cloud wants this
computer enrolled as a trusted device for that session; open the session in
the Claude app instead.

## What it reads from the cloud

These are the addresses Claude Code itself uses for "teleport" (resuming a
cloud session on this computer). They are not a documented public API, so
they could change under it; when one does, the run stops with the address and
the status it got, rather than quietly fetching nothing.

| Step | Address |
|---|---|
| list sessions | `GET /v1/sessions?limit=100&after_id=…` (beta `ccr-byoc-2025-07-29`) |
| a session's log, paged | `GET /v1/code/sessions/cse_…/teleport-events?limit=1000&from_first_event=true`, then `&cursor=…` |
| its helpers' logs, paged | the same, with `&subagents=true`: helper rows only, each naming its helper in `session_agent_id` |
| fallback, one shot | `GET /v1/session_ingress/session/session_…` |

## Tests

```bash
tests/test-fetch-cloud-conversations.sh --dir /mnt/mtwo/programming/ai-stuff
```

A fake cloud answers from prepared files, so the test needs no network and no
sign-in. It covers paging, the fallback feed, the project map, the export,
unchanged runs, a session that grew, a failed export, and the three sign-in
failures.
