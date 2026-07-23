# llama-chat-client.lua

The phone line to the project-local llama.cpp chat server (Qwen3-8B on the GPU
box). Reusable Lua library; also a small CLI for testing the line by hand. All
transcript-summarization code talks to the model *only* through this file, so
there is one place to change the endpoint, the timeout, or the request shape.

- **Endpoint**: defaults to `http://192.168.1.100:20166` (mirrors
  `words-pdf/libs/inference-server-config.lua`). Override at run time with the
  `INFERENCE_CHAT_HOST` env var (replaces `host:port`) or `M.configure{...}`.
- **Server**: start it with `words-pdf/scripts/start-llamacpp-server.sh`. This
  client never launches it; an unreachable endpoint is a loud error.
- **Depends on**: `dkjson` from `${AISTUFF_ROOT}/libs/lua/` (env-overridable),
  and `curl`.

## External functions

| Function | Inputs | Output | Purpose |
|----------|--------|--------|---------|
| `M.configure(opts)` | table `{host, port, model, timeout}` (any subset) | the module (chainable) | Re-point the client or change defaults; omitted fields keep their value. |
| `M.is_reachable()` | — | boolean | True when GET `/v1/models` returns 200 (the same readiness surface the launcher waits on). |
| `M.count_tokens(text)` | string | integer, or `nil, err` | Exact token count via `/tokenize`. Drives chunk sizing so input never overflows the context. Empty string → 0 with no request. |
| `M.chat(messages, opts)` | `messages` = array of `{role, content}`; `opts` = `{temperature=0.3, max_tokens, timeout=300, model}` | assistant text string, or `nil, err` | One chat completion. Content is UTF-8-sanitized before sending. |
| `M.complete(system, user, opts)` | system prompt string, user text string, same `opts` | assistant text string, or `nil, err` | Convenience wrapper for the common one-shot (system + single user block) case. |
| `M.endpoint()` | — | string | The resolved `http://host:port`, for use in caller error messages. |

## Error contract

Every call returns `nil, err` (never throws) on failure, and the `err` string is
categorized so a caller can tell the cases apart:

- **`unreachable: ...`** — curl could not connect (HTTP 000): server down, wrong
  host, or timeout. The message includes the fix (start the server).
- **`server error (HTTP nnn): ...`** — the server answered with an `error`
  object (e.g. a malformed request or an input-too-large batch error).
- **`could not parse reply (HTTP nnn) ...`** — a non-JSON reply.

## CLI (standalone testing)

```
luajit llama-chat-client.lua --ping            # exit 0 if reachable, 1 if not
luajit llama-chat-client.lua --tokens "TEXT"   # print exact token count
luajit llama-chat-client.lua --prompt "TEXT"   # print a completion
```

## Notes / gotchas

- Request bodies are written to unique `os.tmpname()` files and handed to curl
  with `-d @file` — this both avoids shell-escaping large payloads and keeps
  back-to-back calls from reading each other's half-written bodies.
- UTF-8 sanitization matters: the server's JSON parser returns HTTP 500 on
  ill-formed bytes, which real transcripts contain (line-wrapped multi-byte box
  characters are the usual culprit).
- Default chat timeout is 300 s because summarizing a full context-window chunk
  is genuinely slow on an 8B model; lower it via `opts.timeout` for quick probes.
