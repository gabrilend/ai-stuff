# Issue 025: Replace Ollama With llama.cpp Server

## Current Behavior

The project's AI-touching paths all talk to an Ollama HTTP server.
Ollama is a thin convenience layer around its own model registry; it
manages downloads, switches models on the fly, and serves a REST API
that this project consumes in two flavors:

- The **embedding** pipeline used by PDF generation. The default run
  mode (`./run` with no args) goes through `compile-pdf-ai.lua` into
  `libs/fuzzy-computing.lua`, which posts text to `/api/embeddings`
  for every poem and caches the resulting vectors on disk.
- The **chat** pipeline used by the spacebar-expansion chatbot
  (`./run web-chatbot`) and the legacy HTML interface (`./run web-old`).
  Both post conversation context to `/api/chat` and read back text.

The endpoint these callers reach is resolved by `libs/ollama-config.lua`,
which probes three or four hardcoded addresses (the GPU box at
192.168.1.100, localhost in a couple of forms) and exports the first
one that answers `/api/tags`. That config got the project off the
ground but its costs have stacked up:

- Ollama is a third runtime to install and keep happy. The build-deps
  story is now self-contained for CUDA and llama.cpp; Ollama is the
  remaining external dependency that does not live in this repo.
- Ollama's `/api/embeddings` defaults to a 2048-token context window
  regardless of what the underlying model supports, so longer poems
  silently get truncated unless `num_ctx` is set on every request.
- The same model loaded directly under llama.cpp is faster on the
  same hardware for short prompts because there is no tokenizer reload
  on model switch and no JSON pre-processing layer.
- Ollama does not expose batch size, KV-cache strategies, or exact
  layer-offload count — all of which `llama-server` takes as direct
  CLI flags.

The build-side of the replacement has already landed:

- `scripts/build-cuda.sh` puts the CUDA toolkit into `libs/cuda/`.
- `scripts/build-llamacpp.sh` clones, updates, and compiles llama.cpp
  with CUDA support; the result is a working `llama-server` at
  `libs/llama.cpp/build/bin/llama-server`.
- `scripts/build-deps.sh` runs both in order.

The runtime callers — the Lua libraries and the `./run` shell driver
— have not yet been migrated. They still try to reach an Ollama
instance that this project no longer installs.

A survey of the current footprint, in order of "depended upon by what
the user actually runs":

| File | Role |
|---|---|
| `libs/ollama-config.lua` | Resolves which Ollama endpoint to call. |
| `libs/fuzzy-computing.lua` | Posts to `/api/embeddings` for PDF gen. |
| `src/chatbot-server.lua` | Posts to `/api/chat` for `./run web-chatbot`. |
| `src/web-server-old.lua` | Posts to `/api/chat` for `./run web-old`. |
| `test-ollama-embeddings.sh` | Standalone smoke test of the embedding endpoint. |
| `run` | Entry point. Does not currently start any inference server. |

## Intended Behavior

Replace Ollama with two directly-invoked `llama-server` processes —
one for embeddings, one for chat — both binaries living under
`libs/llama.cpp/` and both models living under the project-local
`models/` directory. Hard replace, not coexistence: there is one
inference backend in this codebase, and the configuration surface
shrinks to match.

The new shape:

- `libs/inference-server-config.lua` (renamed from `ollama-config.lua`)
  exposes two endpoint URLs: one for embeddings, one for chat. Each
  defaults to a known host:port pair on the LAN, and each has an
  env-var override for callers who need to point at a different
  instance. No probing — the endpoints are configured, not discovered.
- `libs/fuzzy-computing.lua` posts to `/v1/embeddings`
  (OpenAI-compatible) instead of `/api/embeddings`. The request body
  uses `input` instead of `prompt`; the response is read out of
  `data[1].embedding` instead of `embedding`. `num_ctx` is dropped
  from per-request bodies; context size is set once via `llama-server`'s
  `--ctx-size` flag at launch.
- `src/chatbot-server.lua` and `src/web-server-old.lua` post to
  `/v1/chat/completions` instead of `/api/chat`. The body shape stays
  close (`messages` is the same), but the response is read out of
  `choices[1].message.content` instead of `message.content`.
- A new `scripts/start-llamacpp-server.sh` launches both server
  instances, one per model, on their configured ports. Idempotent:
  re-running while one or both are alive is a no-op for those.
  Skip-if-running is keyed on the port responding to `/v1/models`.
- `run` invokes the launcher early, before any Lua driver starts. The
  Lua scripts can then assume the endpoints are reachable and fail
  loudly (not silently) if they are not.
- The embedding model is `models/nomic-embed-text-v1.5.Q8_0.gguf`
  (already present at the time of writing this issue). The chat model
  is `models/Qwen3-8B-Q4_K_M.gguf` (~5 GB; downloaded as part of
  setting this up).

Endpoint defaults:

| Endpoint | Host | Port | Model | Flags |
|---|---|---|---|---|
| Embeddings | 192.168.1.100 | 20165 | nomic-embed-text v1.5 Q8_0 | `--embeddings -c 2048` |
| Chat | 192.168.1.100 | 20166 | Qwen3-8B Q4_K_M | `-c 4096` |

Both bind to the LAN IP intentionally — the original Ollama setup
exposed the same surface on the same network, and downstream callers
already expect to reach the GPU box at that address.

## Suggested Implementation Steps

1. Rename `libs/ollama-config.lua` to `libs/inference-server-config.lua`
   via `git mv` so the move is tracked. Rewrite the contents to drop
   the probe loop and to expose two endpoint URLs:
   `M.EMBEDDING_ENDPOINT` and `M.CHAT_ENDPOINT`. Each reads an optional
   env-var override (`INFERENCE_EMBEDDING_HOST`, `INFERENCE_CHAT_HOST`)
   and falls back to the LAN defaults. The file ends up shorter than
   the original — the simpler config surface is part of the win here.

2. Update `libs/fuzzy-computing.lua`:
   - Change the `require` to `inference-server-config`.
   - Build the POST body as `{ model = ..., input = text }` instead of
     `{ model, prompt, options = { num_ctx } }`.
   - POST to `/v1/embeddings` instead of `/api/embeddings`.
   - Read `response.data[1].embedding` instead of `response.embedding`.
   - Drop the `num_ctx` parameter throughout the file (it has no place
     once `--ctx-size` is set once at server launch).
   - Update the deprecated `M.generate()` path the same way against
     `/v1/chat/completions` so both code paths talk to the same backend.

3. Update `src/chatbot-server.lua`:
   - Change the `require` to `inference-server-config`.
   - POST to `${CHAT_ENDPOINT}/v1/chat/completions`.
   - Read `response.choices[1].message.content`.
   - Rename `call_ollama` to `call_chat_server` and rename the temp
     files it writes.

4. Update `src/web-server-old.lua` the same way as `chatbot-server.lua`.

5. Write `scripts/start-llamacpp-server.sh`:
   - Hard-coded `${DIR}` at the top, first-positional-arg override.
   - Two skip-if-running checks, one per port, against `/v1/models`.
   - Two `llama-server` invocations in the background, each writing
     its log to `${DIR}/tmp/logs/llamacpp-{embed,chat}.log` and its
     PID to `${DIR}/tmp/llamacpp-{embed,chat}.pid`.
   - Wait-until-ready loop on `/v1/models` for each, with a sensible
     timeout (60s should be plenty given local GPU load times).
   - `--ngl 99` to push all layers to GPU on the 1080 Ti.

6. Update `run`:
   - Right after `mkdir -p` for the `tmp/` subdirs, source/invoke
     `scripts/start-llamacpp-server.sh`.
   - Export `LD_LIBRARY_PATH=${DIR}/libs/cuda/lib64:$LD_LIBRARY_PATH`
     so the server resolves `libcudart.so.12` from the project-local
     CUDA install.

7. Rename `test-ollama-embeddings.sh` to `test-embeddings.sh` and
   rewrite the probe:
   - `GET /v1/models` for liveness.
   - `POST /v1/embeddings` with a one-line input.
   - Confirm the response embedding has the model's expected dimension
     (nomic-embed-text v1.5 is 768).

8. Delete the model-download instructions and any "ollama pull" hints
   from the script. The model files are now project-owned under
   `models/`; there is no out-of-band install step.

## Caveats Worth Recording

- llama-server is single-model per process. The two-port setup is the
  unavoidable consequence — there is no "one server, both endpoints"
  configuration to fall back to.
- The chat path can be code-correct against the OpenAI endpoint shape
  but still non-functional until a chat-capable model is loaded on
  the chat port. Until `models/Qwen3-8B-Q4_K_M.gguf` is in place,
  `./run web-chatbot` and `./run web-old` will fail at the first
  inference call, not at startup.
- Ollama's `/api/tags` (used today by `inference-server-config`-via-
  `validate_server` in some projects, and by `test-ollama-embeddings.sh`
  here) does not exist on llama-server. Liveness checks must move to
  `/v1/models`.
- The 1080 Ti has 11 GB of VRAM. With the two models above quantized
  as listed, total resident weights are roughly 0.15 GB (nomic-embed)
  + 4.8 GB (Qwen3-8B Q4_K_M) = ~5 GB, leaving generous headroom for
  KV caches and intermediate activations. A larger chat model would
  start eating into that budget.

## Related

- Issue 008 (embedding similarity engine) — the original caller that
  defined the embedding API shape this file now updates.
- Issue 001 (ai-chatbot-with-prompt-composition) — the original
  caller that defined the chat API shape this file now updates.
- Sibling project `neocities-modernization`, issue 10-049 — same
  migration applied to that project's larger inference-config layer.
  The shape there is more elaborate (multi-server selection, model
  selection, interactive recovery) because that project's scale
  demands it; words-pdf gets the simpler version because its
  config-shape demands less.
