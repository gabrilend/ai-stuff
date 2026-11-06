# Issue #051: Cloud conversations reach the transcripts

## Current Behavior

`fetch-cloud-conversations` (with `tests/test-fetch-cloud-conversations.sh`,
run against a fake cloud) lists the account's sessions, passes over the
Remote Control ones, downloads every other session's log and its helpers'
logs into `~/.claude/cloud-projects`, and hands each changed session to
`backup-conversations --session`. First run against the real cloud on
2026-11-05 (merged as PR 237 the same day).

What the real cloud holds for this account, as of that run (rerun
`fetch-cloud-conversations --list` for today's numbers; the third column is
the kind):

- **Remote Control sessions** (`environment_kind: bridge`, origin
  `claude_code_cli`) are nearly all of the listing. They ran in Claude Code
  on this computer; the cloud only relayed them to the app. Some have an
  empty log in the cloud, the rest a full copy, and every event of every
  full copy was found in a log under `~/.claude/projects` (22,508 of 22,508,
  checked by event id). Their transcripts already exist through
  `backup-conversations`, one per conversation in the project it ran in, so
  the fetcher passes over them and counts them.
- **Cloud sessions** (`environment_kind: anthropic_cloud`, origin
  `web_claude_ai`): one, "Environment exploration". Fetched with its two
  helpers, who come back without descriptions (see Open questions), so an
  exporting run stops at them.
- **Claude Duet threads are not in the listing at all**, under
  `/v1/sessions` or under `/v1/code/sessions` (the second listing Claude Code
  reads; same 48 sessions). Neither are the cloud sessions of 2026-11-03,
  including the one that built this script. The fetcher does not reach the
  conversations it was written for. Open.

## Intended Behavior

Every conversation the owner's account can see that ran away from this
computer (Duet threads and their helpers, claude.ai/code sessions) ends up as
a transcript in `llm-transcripts/`, through the same parser and the same
naming rules as a local one; each conversation has exactly one transcript;
and running the fetch again with nothing new changes nothing.

## Suggested Implementation Steps

1. ✓ List the account's cloud sessions, following pages; cut to `--limit`
   after the pages are gathered.
2. ✓ Fetch each session's log, oldest first, one event per line, into a
   store of its own (`~/.claude/cloud-projects`), never Claude Code's.
3. ✓ Keep a log only when it or its helpers changed; hand each changed
   session to `backup-conversations --session` with its sessions root
   pointed at the store.
4. ✓ File a session under the project its repository is mapped to, and under
   the home folder otherwise.
5. ✓ Fail out loud on every error: sign-in missing, expired or refused, an
   address that does not answer, an export that fails, a log that comes
   back empty.
6. ✓ Run it on the owner's computer against the real cloud (2026-11-05).
   Paging fields confirmed (`has_more`, `last_id`). A Duet thread does not
   come through: step 9.
7. ✓ Helper agents: the same paged feed, asked with `subagents=true`,
   returns only helper rows, each naming its helper in `session_agent_id`.
   Split into `<session>/subagents/agent-<id>.jsonl`, and describe each in
   `agent-<id>.meta.json` from its launch in the parent's log (an Agent
   call's description; `/<skill> <args>` for a Skill run in a fork, as
   Claude Code writes it), so the exporter names and links them as it does
   local ones.
8. ✓ Pass over Remote Control sessions (`environment_kind: bridge`): the
   local log is the record. `--list` names each session's kind.
9. ○ Find where Duet threads are kept and how they can be read with the
   owner's sign-in, then list and fetch them with their helpers.

## Decisions

- **Reuse Claude Code's sign-in, not an API key.** A cloud session belongs to
  the claude.ai account, and an API key belongs to a Console organisation that
  cannot read it. The token is read from Claude Code's own file and refreshed
  by Claude Code, so this script never handles a refresh token.
- **Read the addresses Claude Code's teleport reads.** They are the only
  ones that return the log in the local shape. They are undocumented, so every
  unexpected answer stops the run and names the address.
- **A store of its own.** Writing into `~/.claude/projects` would make Claude
  Code offer the sessions for `--resume` and mix two writers in one folder.
- **Remote Control: the local log is the record, the cloud copy is not
  fetched.** Asked by the owner 2026-11-05: "prefer the local and avoid
  pulling unnecessarily", unless the cloud copy can hold something the local
  one lacks. It cannot: a Remote Control session runs in Claude Code on this
  computer and stops when it does, so every event is written here first; the
  event-id comparison above found no exception. Fetching them would have
  filed a second transcript of each under the home folder.
- **Helpers are described from the parent's launch.** The cloud's helper
  rows carry no description, and the exporter will not name a helper
  without one. A helper whose launch is not in the parent's log is left
  undescribed, and the export says which; no name is made up for it.
- **One home for unmapped sessions.** Duet threads work in no repository, so
  they cannot be placed by folder. The home folder already has a transcript
  archive (`~/ai/llm-transcripts`), so they go there until a better rule is
  asked for.
- **curl and jq only.** Both are already required by the toolchain; nothing
  new is installed.
- **A test seam for the network** (`CLOUD_HTTP_GET`) rather than a fake
  server, so the test needs no listening port and no extra library.

## Open questions

1. **Where are Duet threads kept?** The owner opens them both in the Claude
   app and on claude.ai in a browser. Neither listing Claude Code's sign-in
   reaches holds them. Next: find the address the app or claude.ai uses
   for a thread, and whether Claude Code's sign-in may read it.
2. **A cloud log starts at its latest compaction.** The paged feed, asked
   `from_first_event=true`, began "Environment exploration" at its
   compaction boundary of 2026-09-30 (`cumulativeDroppedTokens` 3,021,565);
   the conversation before it, and the launches of its two helpers (dated
   2026-09-29), are not in the log. Claude Code's code mentions
   "from_first_event refused for", so the feed may treat the boundary as the
   first event on purpose. Is there a way to ask for the events before it,
   and should the transcript say plainly that it begins mid-conversation?
3. **How should a helper with no description be named?** It happens in the
   cloud (launch before the compaction) and locally too: on 2026-11-05, 172
   of the local `agent-*.meta.json` files had no description, among them
   skills forked by `/code-review`, so `backup-conversations` refuses them as
   well. That rule belongs to the exporter (issue 025) and would settle both.

## Related

- `fetch-cloud-conversations`, `README-fetch-cloud-conversations.md`
- `tests/test-fetch-cloud-conversations.sh`
- `issues/025-capture-subagent-session-logs.md` — the helper layout and
  the description-based names the fetched helpers are written for.
