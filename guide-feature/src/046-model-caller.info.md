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
| `for_role(root, role)` | the endpoint record the role uses now: `name`, `url`, `kind`, `timeout`, `role` and any other field the file gives it |
| `chat(endpoint, messages, opts)` | the reply's text, and `{ usage, seconds, endpoint }` |
| `count_tokens(endpoint, text)` | the exact token count from the endpoint's `/tokenize` |
| `embed(endpoint, texts, opts)` | one vector per text, in the order given |
| `reachable(endpoint)` | whether it answers `GET /v1/models` now |
| `describe(endpoint)` | `'name' (url)`, as messages name it |
| `client` | the client itself |

Refused, as Lua errors:
- by `for_role`: a role with no `use.` line; an endpoint with no `timeout`
  (every call needs a limit, and nothing has a default in code); an
  endpoint with a `key-file` (keys come with issue 402); and everything the
  reader refuses (a `use.` line naming an endpoint that is not there, or
  one of the wrong kind);
- by the calls: chat on an embedding endpoint or an embedding on a chat
  one, before anything is sent; and any failure of the request itself.

A call's error starts with the endpoint's name and address:
`endpoint 'kuvalu-chat' (http://...): unreachable: ...`. It never falls
back to another endpoint.
