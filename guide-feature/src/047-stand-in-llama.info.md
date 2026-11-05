# 047-stand-in-llama — info

A stand-in llama.cpp server, for tests only (issue 401b). The real servers
(401a) run on the owner's machine with real models, and this project
installs neither here. This answers llama-server's routes in its shapes,
on 127.0.0.1 only, on a port the system gives (written to `--port-file`).
With `--parent`, it leaves once that process is gone, so a test that dies
leaves no server behind.

    luajit src/047-stand-in-llama.lua --kind chat|embedding --port-file FILE
           [--replies FILE] [--requests FILE] [--dimensions N] [--parent PID]
           [--key-file FILE]

| Route | Answer |
|---|---|
| `GET /v1/models` | the model list (the readiness check) |
| `POST /v1/chat/completions` | the next scripted reply, with `usage` counted one token a word |
| `POST /tokenize` | one token a word |
| `POST /v1/embeddings` | a stable vector of length 1 per text, listed last first (each item's `index` names its text) |

A chat server answers embeddings with 501 and an embedding server answers
chat with 501, as llama-server does with and without `--embeddings`.

`--replies` is a JSON list, taken in order, the last repeated: a string,
or `{ "content": ..., "delay": seconds }`, or `{ "status": 500, "error":
... }`. `--requests` gets one JSON line per request (`method`, `path`,
`body`), so a test can read every conversation sent.

`--key-file` (issue 402) makes it ask for the key in that file, as
llama-server's `--api-key-file` does: every route but `GET /v1/models` and
`/health` needs `Authorization: Bearer KEY`, and gets 401 "Invalid API
Key" without it. Each logged request then says whether it was
`authorized`; the key is never logged.

| Function | Meaning |
|---|---|
| `new({ kind, replies, requests, dimensions, key })` | a server's state |
| `server:answer(method, path, body, authorization)` | the status and the table one request gets (no socket) |
| `server:serve(port_file)` | listen and answer until killed |
| `tokens(text)`, `embedding(text, n)` | what the stand-in counts and embeds |
| `ADDRESS` | `127.0.0.1`, the only address it listens on |
