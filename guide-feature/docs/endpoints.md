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

Only kuvalu keeps this file. The voices learn their own endpoint, and the
embedder's, from the `endpoints:` section of each canvas kuvalu sends them
(`docs/canvas-format.md`): one line per voice, and since issue 503 one for
`use.embedder`, which every voice's look tool uses.

## Selected at runtime

The file is read again at the start of every turn and every distill, so
editing a `use.` line switches that role on its next turn, with nothing
restarted. Each turn records which endpoint it used, in the log and the
goodbye receipt.

Two scripts, run on kuvalu (issue 402, `src/053-endpoint-tools.lua`):

- `scripts/use-endpoint ROLE NAME` makes that edit safely. It checks first:
  the endpoint is in the file, it is the kind the role needs, it has a
  timeout, its key file (if it has one) can be read, and it answers now and
  takes the key. Only then does it rewrite the one `use.ROLE` line, keeping
  its comment (or add one when the role has none), into `endpoints.part`,
  read that back and check it whole, and rename it over `endpoints`. A turn
  starting meanwhile reads the old file or the new one, never half of one.
  It prints the change:

      $ scripts/use-endpoint fg-sora-2 far-away
      use.fg-sora-2: kuvalu-chat -> far-away

  When any check fails it says why, writes nothing, and exits 1.
- `scripts/list-endpoints` prints every endpoint: its name, kind, whether
  it answers now, its address and the roles that use it, with any problem
  (no timeout, a key file that cannot be read) on the line under it.

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
- a key file that cannot be used (below);
- chat on an embedding endpoint, or an embedding on a chat one.

A failed call is an error naming the endpoint and its address:

    endpoint 'kuvalu-chat' (http://192.168.1.100:21223): unreachable: ...

The tests run against a stand-in llama.cpp server on 127.0.0.1
(`src/047-stand-in-llama.lua`), which answers the same four routes in the
same shapes, since this project installs no llama.cpp or models outside
the owner's machines.

## Keys for outside providers

An endpoint with a `NAME.key-file` needs a key, as llama-server started
with `--api-key` does and as most outside providers do (issue 402). The
model caller reads the key from that file at the start of each turn
(`load_key` in `src/046-model-caller.lua`) and sends it with every request
as `Authorization: Bearer KEY`. It refuses, naming the endpoint and the
file but never the key:
- a key file inside the project (keys live outside the repository);
- a key file that is missing or cannot be read;
- a key file that does not hold one key on one line.

`~` in the path is the home folder of whoever runs the turn. Keep the file
readable only by that user (`chmod 600`).

The key never goes on a command line, where any other program on the
machine could read it: the client writes the header to a temporary file
only its owner can read, hands that to curl as `-H @file`, and removes it
when the request is done. It is never written to a log, a receipt or a
canvas. The tests check each of these against a stand-in server that asks
for a key (`src/054-test-endpoint-tools.lua`).

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
use in the canvas it sends: an `endpoints:` section with one line for each
voice, giving that voice's endpoint's name, timeout, address and, for an
endpoint that needs a key, the path of its key file
(`docs/canvas-format.md`). kuvalu reads `endpoints` again for every version
it sends, so `scripts/use-endpoint` on kuvalu reaches a voice with the next
version. A voice keeps no list of its own: its turn uses the line in the
canvas it is answering (`from_canvas` in `src/046-model-caller.lua`).

The key itself never travels in a canvas, only the path of its file. Each
voice that uses an outside provider needs that key file at that path on
its own machine (issue 703). A voice the canvas names no endpoint for, or
whose key file is missing, fails that turn, saying which.

(Until issue 402 this was a single `endpoint` header, the same for every
voice. It could not say that one voice uses another endpoint, which the
file's `use.` lines allow, so 402 replaced it with a line per voice.)
