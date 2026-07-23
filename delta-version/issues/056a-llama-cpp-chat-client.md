# Issue 056a: llama.cpp Chat Client Library

**Phase**: 0 - Tooling
**Status**: Open (in progress)
**Priority**: High (foundation for 056b/c/d)
**Created**: 2026-07-06
**Parent**: 056 (Recursive Transcript Summarization)
**Dependencies**: None (foundation). A running llama.cpp chat server for live use.

---

## Current Behavior

The project-local inference stack is a llama.cpp server (words-pdf, "Issue 025"): Qwen3-8B at
`192.168.1.100:20166`, OpenAI-compatible `/v1/chat/completions`, plus `/tokenize` and `/v1/models`.
The only Lua code that talks to it (`words-pdf/libs/fuzzy-computing.lua`) calls `/v1/embeddings`;
its deprecated `M.generate` shows the chat shape but is embedded in that project. Delta-version has
no reusable **text-generation** client. Issue 049d sketched one for **Ollama** (`/api/generate`),
which is the wrong endpoint now.

---

## Intended Behavior

A small, generic Lua library `scripts/libs/llama-chat-client.lua` that:

1. **Resolves the endpoint** the way `words-pdf/libs/inference-server-config.lua` does: default
   `192.168.1.100:20166`, overridable by `INFERENCE_CHAT_HOST` (replaces `host:port`) or a
   `M.configure{host,port}` call. No probing, no silent fallback — an unreachable endpoint is a
   loud error (house rule).
2. **Sends a chat completion**: `M.chat(messages, opts)` and a convenience `M.complete(system,
   user, opts)`. Returns the assistant text, or `nil, err`. `opts`: `temperature`, `max_tokens`,
   `timeout`, `model`.
3. **Counts tokens exactly**: `M.count_tokens(text)` POSTs to `/tokenize` and returns the integer
   count — this lets 056b size chunks precisely instead of guessing chars-per-token.
4. **Reports reachability**: `M.is_reachable()` (GET `/v1/models`).
5. **Sanitizes UTF-8** before sending (the server's JSON parser 500s on ill-formed bytes, which
   real transcripts contain).
6. Ships a small **CLI** for standalone testing: `--ping`, `--tokens "text"`, `--prompt "text"`.

---

## Suggested Implementation Steps

1. Require `dkjson` from the shared `ai-stuff/libs/lua/` (constant `AISTUFF_ROOT`, env-overridable),
   matching how other tools hard-code the shared libs root.
2. `http_post_json(path, body, timeout)` — encode with dkjson, write to `os.tmpname()`, `curl -sS
   --max-time <t> -X POST <endpoint><path> -d @file`, read+decode the reply, surface `.error`.
   Unique temp files per call (concurrency-safe, per the words-pdf note).
3. `http_get(path, timeout)` for `/v1/models` and simple probes.
4. Parse `.choices[1].message.content` for chat; `#result.tokens` for `/tokenize`.
5. Generous default chat timeout (summarizing a full chunk is slow): ~300 s, configurable.
6. Companion `llama-chat-client.info.md` describing each external function's inputs/outputs.

## Implementation Details

- Request body: `{ model = <alias>, messages = <array of {role,content}>, temperature, max_tokens }`.
- `/tokenize` body: `{ content = <text> }` → reply `{ tokens = [ ... ] }`.
- Errors are categorized in the message (unreachable vs. server-error vs. parse-fail) so callers
  can tell a down server from a bad request.

## Related Documents
- `056-recursive-transcript-summarization.md` (parent).
- `words-pdf/libs/inference-server-config.lua`, `words-pdf/libs/fuzzy-computing.lua` (patterns reused).

## Metadata
- **Priority**: High
- **Complexity**: Low-Medium
- **Dependencies**: `luajit`, `curl`, `dkjson`; a running chat server for live calls.
- **Impact**: The single choke-point through which all transcript summarization talks to the model.

## Success Criteria
- `--ping` reports reachable/unreachable truthfully and exits non-zero when down.
- `--tokens "hello world"` prints an integer token count when the server is up.
- `--prompt "..."` returns a completion.
- Unreachable endpoint yields a clear error, not a hang or a silent nil.
- Uses vimfolds, the `${DIR}` convention, and has an `.info.md` companion.
