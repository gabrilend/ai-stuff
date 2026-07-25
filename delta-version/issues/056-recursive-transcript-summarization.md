# Issue 056: Recursive Transcript Summarization & Table-of-Contents

**Phase**: 0 - Tooling
**Status**: Open (in progress)
**Priority**: High
**Created**: 2026-07-06
**Related**: 049 (LLM Transcript Abstraction Viewer), 049d (Ollama Processing Pipeline — superseded endpoint), 052 (Ollama Connection Config — superseded endpoint), 040g (Transcript Analysis Memory)

---

## Current Behavior

Every Claude Code session leaves a raw log at `~/.claude/projects/<dashed-cwd>/<session-uuid>.jsonl`.
A mature backup toolchain already turns those logs into human-readable markdown:

- `scripts/backup-conversations` (`write-transcripts-to-project-directory`) reads a project's
  JSONL sessions and writes one clean-prose `.md` per conversation into that project's
  `llm-transcripts/` directory. Tool calls and tool results are dropped; the assistant's
  narration prose is kept. Output is routed by mapping the project's absolute path to its
  `~/.claude/projects/-<dashed-path>` directory.
- `scripts/libs/transcript-discovery.sh` is the shared rulebook: it recognizes a real transcript
  by its first line (`# Conversation Summary: <conv-id>`) rather than by filename, builds
  date-token filenames (`transcript_span_basename` → e.g. `jul-3-26`), resolves same-day
  collisions with `_agent-N` suffixes, and finds a conversation's existing file by header id
  (`transcript_find_claim`) so re-runs are idempotent.
- `scripts/migrate-transcript-names.sh` renamed the old `<uuid>_summary.md` files onto the
  date scheme (via `git mv`), keyed off `transcript_is_new_format` (a **filename** regex).
- `scripts/batch-transcript-backup.sh` drives the backup across every `llm-transcripts/` in the
  monorepo, with verbosity levels and `--since`.

### Current Issues

- The `.md` transcripts have **no summary**. To know what a session was about you must read the
  whole thing. Some are huge (`FULL-TRANSCRIPT-EXPORT.md` ≈ 3 MB; single agent logs ≈ 137 KB).
- Filenames are bare dates (`dec-10-25.md`); they say *when* a session happened but not *what*
  it did.
- There is no index — no per-repo "table of contents" that lets you skim every session at a
  glance.
- No local-LLM summarization exists. Issue 049d sketched an **Ollama** client, but the working
  inference stack has since migrated to a project-local **llama.cpp** server (words-pdf, "Issue
  025"): `words-pdf/scripts/start-llamacpp-server.sh` serves Qwen3-8B (Q4_K_M) at
  `192.168.1.100:20166` on an OpenAI-compatible `/v1/chat/completions`. There is no reusable Lua
  chat client for it (the words-pdf AI code only calls `/v1/embeddings`).

---

## Intended Behavior

A local-LLM pipeline that reads each session's clean-prose transcript and produces three things,
then folds them back into the file and a per-repo index:

1. **A recursive (map-reduce) summary.** Most sessions overflow a single context window, so the
   engine reads as much as fits, summarizes that chunk, moves to the next, and so on — then
   recursively summarizes the summaries (summaries become the next context) until a single final
   summary remains.
2. **A one-sentence title.** The final summary is boiled down to a single sentence, slugified,
   and combined with the session's date to form the **new filename**: `<slug>-<date>.md`
   (e.g. `set-up-recursive-transcript-summarizer-dec-10-25.md`).
3. **A medium table-of-contents paragraph.** One paragraph per session, appended to a per-repo
   `llm-transcripts/table-of-contents.md`, and also **prepended into the transcript itself** (just
   under the header) so a reader opens the file, reads the summary, then reads the full text if
   they want.

An **overseer** discovers un-summarized sessions across configured repositories (work-list anchored
on `~/.claude/projects/`, filtered by a config file), ensures each has been exported to its repo's
`llm-transcripts/`, and runs the summarizer on any transcript that lacks a summary marker. It is
**idempotent** (skips already-summarized files) and run **manually or by cron** (no session-close
hook).

---

## Architecture & Data Flow

```
                          ~/.claude/projects/<dashed-cwd>/<uuid>.jsonl   (raw session logs — the source)
                                        |
        [existing] backup-conversations |  (JSONL -> clean-prose markdown, tool noise dropped)
                                        v
   <repo>/llm-transcripts/<date>.md   ("# Conversation Summary: <id>" + User/Assistant prose)
                                        |
   ------------------------------------ | ------------------------------------  NEW (issue 056)
                                        v
        (056a) llama-chat-client.lua  --- talks to Qwen3-8B at /v1/chat/completions, /tokenize
                                        |
        (056b) summarize-transcript.lua  MAP:   chunk-to-fit -> summarize each chunk
                                        |       REDUCE: summarize the summaries, recurse to one
                                        |       TITLE:  final summary -> one sentence
                                        |       BLURB:  final summary -> medium paragraph
                                        v       (emits structured result: title, slug, blurb, summary)
        (056c) apply-summary.sh        git mv  <date>.md -> <slug>-<date>.md
                                        |       prepend blurb block under the header (idempotency marker)
                                        |       append blurb to <repo>/llm-transcripts/table-of-contents.md
                                        v       grep+fix any references to the old name
        (056d) summarize-overseer.sh   walk configured repos (from ~/.claude + config), for each
                                        transcript with no summary marker: run 056b -> 056c.
```

Two concerns are kept isolated, per house rules (data generation vs. data viewing):
**Lua does the LLM/text generation** (client + engine); **bash does the filesystem/git mutation**
(applier + overseer, which source the shared `transcript-discovery.sh`).

---

## Sub-Issues

| Issue | Component | Role |
|-------|-----------|------|
| **056a** | `llama-chat-client.lua` | Foundation: curl+JSON client for the llama.cpp `/v1/chat/completions` and `/tokenize` endpoints; endpoint config + env override; retry; exact token counts. |
| **056b** | `summarize-transcript.lua` | Recursive map-reduce summarizer over one transcript's text; emits title, slug, blurb, final summary. Pure text in → structured out. |
| **056c** | `apply-summary.sh` | Renames the file (`git mv`), prepends the blurb block, updates the per-repo table-of-contents, fixes references. Extends `transcript-discovery.sh` to recognize the summarized name scheme. |
| **056d** | `summarize-overseer.sh` + `config/transcript-summary-repos.conf` | Discovers un-summarized sessions across configured repos, ensures export, runs 056b→056c idempotently. Manual/cron. |

Ordered foundational → capstone: 056a is a dependency of 056b; 056b feeds 056c; 056d orchestrates all.

---

## Suggested Implementation Steps

### 1. (056a) llama.cpp chat client library
- New: `scripts/libs/llama-chat-client.lua` (+ `.info.md`).
- Model the endpoint resolution on `words-pdf/libs/inference-server-config.lua`: default
  `192.168.1.100:20166`, overridable with `INFERENCE_CHAT_HOST` (replaces host:port). Fail loudly
  on an unreachable endpoint rather than silently degrading (house rule: errors over fallbacks).
- HTTP via `curl` in `io.popen` (same approach as 049d's sketch and words-pdf's AI code): POST a
  JSON body to `/v1/chat/completions`, parse the assistant message out of the response.
- Add `count_tokens(text)` that POSTs to the server's `/tokenize` endpoint and returns the exact
  token count — this drives the chunker in 056b instead of a char estimate.
- Provide `is_reachable()` and a small CLI (`--ping`, `--prompt "..."`) for standalone testing.

### 2. (056b) Recursive map-reduce summarizer
- New: `scripts/summarize-transcript.lua` (+ `.info.md`). Reads a transcript file, returns a
  structured result. No file mutation here — that is 056c's job.
- **Chunk-to-fit**: split the body on turn boundaries (`### User Request` / `### Assistant
  Response`, the markers the exporter writes) so a chunk never bisects a turn; grow a chunk until
  `count_tokens` approaches the input budget = `context - reserved_output - prompt_overhead`.
- **Map**: summarize each chunk with a "summarize this slice of a dev session" prompt.
- **Reduce**: concatenate the chunk summaries; if they still exceed the budget, group and
  summarize again; recurse until one final summary fits. Log each level's fan-in.
- **Title & blurb**: two more passes over the final summary — one yields a single sentence, one a
  medium paragraph. Slugify the sentence (lowercase, ascii, `[a-z0-9]+` joined by `-`, capped
  ~60 chars).
- Emit the result as a small structured blob (title, slug, blurb, final_summary) for 056c to
  consume — a temp file under the project `tmp/` symlink (RAM), not stdout-scraping.

### 3. (056c) Summary applier
- New: `scripts/apply-summary.sh`; sources `../../scripts/libs/transcript-discovery.sh` (absolute).
- Compute the new base = `<slug>-<existing-date-token>`; `git mv` old → new (both tracked, per
  house rule), reusing `transcript_pick_free_name` for `_agent-N` collisions.
- Prepend the blurb block under the header with an idempotency marker (see Implementation Details).
- Append the blurb (with a link to the file) to `<repo>/llm-transcripts/table-of-contents.md`,
  creating it if absent.
- **Respect the naming authority (scripts issue 020)**: the exporter
  (`backup-conversations`) is the one and only program that names transcript files, and it
  re-derives every name from the session JSONL after every assistant reply. As designed above,
  a `<slug>-<date>.md` rename would be REVERTED on the next Stop hook for any conversation
  whose JSONL still exists: the exporter compares its claim's stripped basename against the
  derived date-span base, sees a mismatch, re-places the file at the bare date name and
  deletes the slug-named claim. Before the applier renames anything, teach the shared
  rulebook (`transcript-discovery.sh`) a claim-equivalence rule — a claim whose name *ends
  with* the derived date token is already in scheme — and route the exporter's claim
  comparison through it. Widen `transcript_is_new_format` the same way. The one-shot
  migrator this bullet used to worry about is retired; the exporter is the only enforcer
  left, and it must learn slug names before they exist. Grep the monorepo for other
  consumers of these functions.
- Grep `delta-version/scripts/reconstruct-history.sh` and `test-transcript-provenance.sh` (the
  provenance tooling) for filename references and update any that break.

### 4. (056d) Overseer + repo config
- New: `scripts/summarize-overseer.sh` and `config/transcript-summary-repos.conf` (seeded — see
  Implementation Details).
- Build the work-list from `~/.claude/projects/` (authoritative session list, incl. non-ai-stuff
  repos): read the `cwd` field *inside* each JSONL (robust; the dashed dir names are ambiguous
  because `.` and `/` both encode to `-`). Keep a repo if it is under the ai-stuff root OR listed
  in the config.
- For each kept repo: ensure sessions are exported (delegate to `backup-conversations`), then for
  every transcript in `llm-transcripts/` lacking the summary marker, run 056b → 056c.
- Skip already-summarized files (marker check). Support `--dry-run`, `--dir <repo>` (single repo),
  and `--commit`.

---

## Implementation Details

### Endpoint & model
- Server: `words-pdf/scripts/start-llamacpp-server.sh` (chat instance, port 20166, Qwen3-8B
  Q4_K_M, `--ctx-size 16384`). It must be running; the overseer/engine fail loudly if the
  endpoint is unreachable and tell the operator to start it. Binary:
  `words-pdf/libs/llama.cpp/build/bin/llama-server`.
- The engine uses the server's `/tokenize` for exact chunk sizing so it never trips the
  "input too large" batch error.

### Chunk budget (per level)
`input_budget = ctx_size − reserved_output − prompt_overhead`. With ctx 16384, ~1024 reserved for
the summary and ~512 for the instruction, budget ≈ 14.8k tokens per chunk. Configurable.

### Idempotency marker & in-file layout
The header line stays first (keeps `transcript_is_summary` working). The blurb block is inserted
right after it:

```
# Conversation Summary: <conv-id>
<!-- transcript-summary v1 -->
## Session Summary
<medium table-of-contents paragraph>

--------------------------------------------------------------------------------
... original Generated-on line and body unchanged ...
```

"Already summarized?" = the file contains the `<!-- transcript-summary v1 -->` marker. The overseer
and applier both key off this, never off the filename.

### Filename scheme
`<slug>-<date-token>.md`, where `<date-token>` is the existing `mon-d-yy` token (or `-through-`
span). Example: `dec-10-25.md` → `set-up-recursive-transcript-summarizer-dec-10-25.md`. This
requires widening `transcript_is_new_format` (above).

### Config format (`config/transcript-summary-repos.conf`)
INI-style, mirroring `config/external-projects.conf`. `[settings]` toggles auto-including every
ai-stuff repo; `[extra_repos]` lists absolute paths of non-ai-stuff repos to also summarize; seeded
from the repos actually present in `~/.claude/projects/`. See the file's own header for the field
docs.

### Prompts
Kept in the engine, each a plain instruction + the slice. Temperature low (~0.3) for stable,
factual summaries. Prompts describe the material as "a slice of a software-development session
transcript between a user and an AI assistant" and ask for decisions, mechanisms, and outcomes —
not pleasantries.

---

## Related Documents
- `049-llm-transcript-abstraction-viewer.md` — broader multi-abstraction viewer; shares the
  transcript-processing goal. This issue is the summarization-and-index slice, on llama.cpp.
- `049d-ollama-processing-pipeline.md` — prior LLM-client sketch; endpoint superseded (Ollama →
  llama.cpp) but the retry/JSON/http_post shape is reused.
- `scripts/libs/transcript-discovery.sh` (in `ai-stuff/scripts/`) — the shared rulebook this
  builds on and extends.
- `words-pdf/scripts/start-llamacpp-server.sh`, `words-pdf/libs/inference-server-config.lua` —
  the inference stack and endpoint config being reused.

## Tools Required
- `luajit`, `curl`.
- A running llama.cpp chat server (Qwen3-8B) — started via `words-pdf/scripts/start-llamacpp-server.sh`.
- The existing backup toolchain in `ai-stuff/scripts/` (for the overseer's export step).

## Metadata
- **Priority**: High
- **Complexity**: High
- **Dependencies**: llama.cpp server (words-pdf), `transcript-discovery.sh`, backup toolchain.
- **Impact**: Every session becomes skimmable by title and summary; a per-repo index appears;
  filenames become self-describing. Touches a shared library, so coupling is documented above.

## Success Criteria
- A large transcript (> one context window) is summarized to a single coherent final summary via
  recursive reduction, with each level logged.
- A one-sentence title is produced and the file is `git mv`d to `<slug>-<date>.md`.
- A medium paragraph is prepended under the header AND appended to the per-repo
  `table-of-contents.md`.
- Re-running the overseer skips already-summarized files (marker-based idempotency).
- The migrator (`migrate-transcript-names.sh`) no longer tries to rename summarized files.
- The provenance tooling still resolves transcripts after the rename.
- New source files carry `.info.md` companions and use vimfolds + the `${DIR}` convention.

---

## Follow-up (not this issue)
- CLAUDE.md project-initialization should register each new project in
  `config/transcript-summary-repos.conf` so non-ai-stuff repos are covered automatically. (User to
  add the CLAUDE.md rule.)
