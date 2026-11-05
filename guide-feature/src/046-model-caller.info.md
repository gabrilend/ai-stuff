# 046-model-caller — info

Which endpoint a role uses, and the calls to it (issue 401b). The
project-root `endpoints` file (`docs/endpoints.md`) is read again every
time a role's endpoint is asked for, never cached, so an edited `use.` line
switches that role on its next turn with nothing restarted. The calls go
through this project's copy of the llama.cpp client,
`libs/llama-chat-client.lua` (`docs/vendored-code.md`).

| Function | Meaning |
|---|---|
| `read(root)` | the endpoints file, checked (001's `read_endpoints`) |
| `for_role(root, role)` | the endpoint record the role uses now: `name`, `url`, `kind`, `timeout`, `role` and any other field the file gives it, with `key` read from its key file |
| `from_canvas(record, voice, root)` | a voice's endpoint for this turn, from its line in the canvas's `endpoints:` section (issue 402), its key read on this machine. With `"embedder"` for the voice, the embedder's line (503), an embedding endpoint |
| `load_key(endpoint, root)` | reads the endpoint's `key-file` into `endpoint.key`; an endpoint with none is left alone |
| `chat(endpoint, messages, opts)` | the reply's text, and `{ usage, seconds, endpoint }` |
| `count_tokens(endpoint, text)` | the exact token count from the endpoint's `/tokenize` |
| `embed(endpoint, texts, opts)` | one vector per text, in the order given |
| `model_name(endpoint)` | the model the endpoint serves, the first `GET /v1/models` lists (issue 502) |
| `reachable(endpoint)` | whether it answers `GET /v1/models` now |
| `describe(endpoint)` | `'name' (url)`, as messages name it |
| `client` | the client itself |

Refused, as Lua errors:
- by `for_role`: a role with no `use.` line; an endpoint with no `timeout`
  (every call needs a limit, and nothing has a default in code); and
  everything the reader refuses (a `use.` line naming an endpoint that is
  not there, or one of the wrong kind);
- by `from_canvas`: a voice the canvas names no endpoint for;
- by `load_key` (from both): a key file inside the project, missing or
  unreadable, or not holding one key on one line. The error names the
  endpoint and the file, never the key;
- by the calls: chat on an embedding endpoint or an embedding on a chat
  one, before anything is sent; and any failure of the request itself.

A call's error starts with the endpoint's name and address:
`endpoint 'kuvalu-chat' (http://...): unreachable: ...`. It never falls
back to another endpoint.
