# The endpoints file

The owner: "let's implement this using llama.cpp. We can run on kuvalu for
now, but make sure there's a config file in the project root that allows us
to set multiple endpoints that can be selected from at runtime."

Every language model and embedding model guide-feature uses is a llama.cpp
server, reached over HTTP with its OpenAI-style routes
(`/v1/chat/completions`, `/v1/embeddings`, `/tokenize`, `/v1/models`). The
file `endpoints` in the project root names them all, and says which one each
part uses.

## Format

The same `name.field = value` lines as rmail's `contacts` file: `#` starts a
comment, text in "quotes", bare whole numbers.

    # -- the endpoints --------------------------------------------------
    kuvalu-qwen.url      = "http://192.168.1.100:20166"   # placeholder port
    kuvalu-qwen.kind     = "chat"
    kuvalu-qwen.timeout  = 300

    kuvalu-embed.url     = "http://192.168.1.100:20167"
    kuvalu-embed.kind    = "embedding"
    kuvalu-embed.timeout = 60

    # a provider outside the house; its key never goes in this file
    far-away.url         = "https://example.invalid/llama"
    far-away.kind        = "chat"
    far-away.key-file    = "~/.config/guide-feature/keys/far-away"

    # -- who uses which -------------------------------------------------
    use.fg-sora-1  = "kuvalu-qwen"
    use.fg-sora-2  = "kuvalu-qwen"
    use.fg-sora-3  = "kuvalu-qwen"
    use.distiller  = "kuvalu-qwen"
    use.embedder   = "kuvalu-embed"

| Field | Type | Meaning |
|---|---|---|
| `NAME.url` | text | where the llama.cpp server answers |
| `NAME.kind` | `chat` or `embedding` | what it is for. A `use.` line that points a chat role at an embedding endpoint is an error |
| `NAME.timeout` | whole number of seconds | how long one request may take. Every endpoint a role uses needs one: nothing has a default in code |
| `NAME.model` | text, a path to a model file | only for servers this project starts itself: the model `scripts/start-servers` loads |
| `NAME.port` | whole number | only for servers this project starts itself: the port it listens on |
| `NAME.key-file` | text, a path outside the repository | for endpoints that need a key: the file holding it. The key itself is never in `endpoints` |
| `use.ROLE` | an endpoint name | which endpoint a role uses. Roles: each voice by name, `distiller`, `embedder` |

## Selected at runtime

The file is read again at the start of every turn and every distill, so
editing a `use.` line switches that role on its next turn, with nothing
restarted. `scripts/use-endpoint ROLE NAME` makes that edit and checks the
endpoint answers before writing it. Each turn records which endpoint it used,
in the log and the goodbye receipt.

A file that does not parse, a `use.` line naming an endpoint that does not
exist, or an endpoint that does not answer is an error for that turn. There
is no quiet switch to another endpoint: the canvas would then look as if one
model wrote it when another did.

## The client

The requests go through this project's own copy of delta-version's
llama.cpp client, `libs/llama-chat-client.lua` (`docs/vendored-code.md`):
chat, exact token counts, and a reachability check, plus an embedding call
added here. Each call is handed the endpoint record it goes to, so every
role reaches its own endpoint. It needs `curl` and `libs/dkjson.lua`.
Whether the mini-computers' BusyBox userland has `curl` is checked in
phase 7.

The model caller, `src/046-model-caller.lua` (issue 401b), sits on top:
`for_role(root, role)` reads the file again and returns the endpoint the
role uses now, and `chat`, `count_tokens`, `embed` and `reachable` call it.
It refuses, before sending anything:
- a role with no `use.` line;
- an endpoint with no `timeout`;
- an endpoint with a `key-file`, until issue 402 sends keys;
- chat on an embedding endpoint, or an embedding on a chat one.

A failed call is an error naming the endpoint and its address:

    endpoint 'kuvalu-chat' (http://192.168.1.100:21223): unreachable: ...

The tests run against a stand-in llama.cpp server on 127.0.0.1
(`src/047-stand-in-llama.lua`), which answers the same four routes in the
same shapes, since this project installs no llama.cpp or models outside
the owner's machines.

## The servers

guide-feature runs its own llama.cpp servers, built from its own clone
(`libs/llama.cpp/`, cloned from words-pdf's local checkout as its upstream)
and started and stopped by its own scripts:

- `scripts/start-servers` starts every endpoint in `endpoints` that lists a
  `NAME.model` file and a `NAME.port` on this machine, waits until each
  answers, and writes its process number to `tmp/shared-memory/servers/`.
- `scripts/stop-servers` stops them, so the GPU is free when guide-feature is
  not running.

No other project's server is used, and starting this project's servers never
depends on another project being set up. The example addresses above (port
20166 and its neighbour) are placeholders. This project's real ports are
chosen in issue 401a, away from the ports other projects use.

The `endpoints` file in the project root (issue 401b) proposes 21223 for
the chat server and 21224 for the embedding server. No file in the
monorepo uses either as a port. 401a confirms them against what kuvalu
already listens on before anything starts there, and adds each server's
`NAME.model` once the models are chosen with the owner.

## Where the file lives

Only kuvalu keeps `endpoints`. kuvalu tells each voice which endpoint to
use in the canvas it sends: an `endpoint` header with the endpoint's name
and address (`docs/canvas-format.md`). Switching every voice is then one
edit, in one place. A voice keeps no list of its own and uses the header
it was last sent.
