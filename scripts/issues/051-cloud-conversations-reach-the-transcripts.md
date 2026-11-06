# Issue #051: Cloud conversations reach the transcripts

## Current Behavior

Built 2026-11-03 as `fetch-cloud-conversations`, with
`tests/test-fetch-cloud-conversations.sh` (30 of 30 against a fake cloud). A
real cloud session's log (the session that built this, its first 400 lines)
went through `backup-conversations --session` unchanged and came out as a
transcript. **Not yet run against the real cloud**: the container that built
it has no Claude Code sign-in of the owner's. Step 6 is that run.

What follows is the problem as it was first described.

Conversations in Claude Duet (and any claude.ai/code session) run in the
cloud. They never write to `~/.claude/projects` on this computer, so the
backup scripts cannot see them, and none of them has a transcript. The owner,
2026-11-03: "let's draft that fetcher and integrate it into the
llm-transcripts system."

## Intended Behavior

Every cloud session the owner's account can see ends up as a transcript in
`llm-transcripts/`, through the same parser and the same naming rules as a
local one, and running the fetch again with nothing new changes nothing.

## Suggested Implementation Steps

1. ✓ List the account's cloud sessions, following pages.
2. ✓ Fetch each session's log, oldest first, one event per line, into a
   store of its own (`~/.claude/cloud-projects`), never Claude Code's.
3. ✓ Keep a log only when it changed; hand each changed log to
   `backup-conversations --session` with its sessions root pointed at the
   store.
4. ✓ File a session under the project its repository is mapped to, and under
   the home folder otherwise.
5. ✓ Fail out loud on every error: sign-in missing, expired or refused, an
   address that does not answer, an export that fails.
6. ○ Run it once on the owner's computer against the real cloud; check the
   listing's paging fields and that a Duet thread comes through.
7. ○ Helper agents (subagents) of a cloud session: the paged feed can return
   them (`subagents=true`, rows carry `session_agent_id`). Fetch them into
   `<session>/subagents/` so their transcripts sit beside the parent's.

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
- **One home for unmapped sessions.** Duet threads work in no repository, so
  they cannot be placed by folder. The home folder already has a transcript
  archive (`~/ai/llm-transcripts`), so they go there until a better rule is
  asked for.
- **curl and jq only.** Both are already required by the toolchain; nothing
  new is installed.
- **A test seam for the network** (`CLOUD_HTTP_GET`) rather than a fake
  server, so the test needs no listening port and no extra library.
