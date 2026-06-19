# Issue 10-049: Replace Ollama With llama.cpp

## Current Behavior

The embedding-generation pipeline talks to an Ollama HTTP server for
every embedding call. Ollama is a thin convenience wrapper around its
own model registry; it manages model downloads, switches models on
the fly, and exposes a REST API at `/api/embeddings` and friends.
The project has been using it because it was the easiest way to get
the embedding step running, but several costs have stacked up over
time:

- Ollama's server is a third dependency to install, run, and keep
  running. The current setup keeps it alive via
  `scripts/start-ollama-cuda.sh` and depends on it being reachable at
  a configured host:port.
- Ollama's CUDA build choices have not always matched what the local
  GPU expects, contributing to past slow embedding generation that
  was hard to diagnose without driver-level insight.
- The same model loaded under Ollama's runtime is slower than under
  a more direct inference engine for short prompts because Ollama
  reloads tokenizers and warms caches on each model switch.
- Ollama's API does not expose all of the inference-runtime knobs
  that llama.cpp exposes directly (batch size, KV-cache strategies,
  exact thread count for CPU layers, etc.).

The codebase has built up its own abstractions on top of this:
`libs/ollama-config.lua` resolves which server and model to use,
`src/ollama-manager.lua` does liveness checking and warmup, and
about nineteen other files reference the term "ollama" in some form
(config sections, CLI flags, environment variables, doc comments,
log strings).

Run the survey to see the current footprint:

```bash
grep -rln -i "ollama" src/ libs/ scripts/ config.lua run.sh generate-embeddings.sh
```

## Intended Behavior

Replace Ollama with a directly-invoked llama.cpp `llama-server`
process that serves the configured embedding model over an
OpenAI-compatible HTTP endpoint. The replacement is a **hard
replace**, not a coexistence: Ollama support is removed entirely,
the codebase has exactly one inference backend, and the configuration
surface shrinks to match.

The new shape:

- A `scripts/build-deps.sh` (new, or extension of an existing script)
  clones and builds llama.cpp with CUDA support, downloads the
  configured embedding model as a GGUF file, and verifies the build
  by running a single test embedding request.
- A `libs/inference-server-config.lua` (renamed from `ollama-config.lua`)
  resolves which llama-server instance and which model the rest of
  the pipeline should call. The shape of the config matches what
  `ollama-config.lua` exposes today, just with vocabulary swapped:
  `inference_servers` instead of `ollama_servers`,
  `default_inference_server` instead of `default_ollama_server`,
  `get_selected_server` / `get_selected_model` / `build_host_url`
  with identical semantics.
- A `scripts/start-llamacpp-server.sh` (new, replacing
  `start-ollama-cuda.sh`) starts the server process bound to the
  configured port, serving the configured model, with the
  `--embedding` flag so the embedding endpoints are active. Restart
  semantics match what the operator expects from the old script.
- All callers of the embedding endpoint use the new path. The
  OpenAI-compatible endpoint at `/v1/embeddings` is preferred because
  the request/response shape matches what most ecosystem tools
  expect, and because it gives us forward compatibility with any
  other server that speaks the same protocol.

The behavior change is invisible to downstream consumers of the
embedding cache: `embeddings.json` continues to live at
`assets/embeddings/<model-dir>/embeddings.json` with the same
schema, and the diversity / similarity / HTML stages do not need
to know which backend produced it.

## Suggested Implementation Steps

### Build-side preparation (parallel to runtime changes)

1. Write `scripts/build-deps.sh` (or extend if a file already exists
   in the project root). Hard-code the canonical project DIR at the
   top with the option to override via the first positional argument,
   per the project convention. The script:
   - Checks for and installs (or surfaces an install command for)
     the required build prerequisites: cmake (>= 3.14), gcc,
     git, vulkan-headers (already present in the project), and the
     CUDA toolkit components. Use distro-appropriate package names.
   - Clones https://github.com/ggml-org/llama.cpp into
     `$DIR/libs/llama.cpp` (or refreshes if already cloned).
   - Configures with CUDA enabled
     (`cmake -DLLAMA_CUDA=ON ..`) and builds with `make -j$(nproc)`.
   - Downloads the configured embedding model's GGUF file into
     `$DIR/assets/models/<model>.gguf`. The model name + URL pair
     comes from `config.lua` so a future model swap is a single
     config edit.
   - Verifies by launching `llama-server --embedding` against the
     model and sending one test embedding request.
2. Write `scripts/start-llamacpp-server.sh` mirroring the shape of
   `start-ollama-cuda.sh`. Read host, port, and model path from
   `config.lua` so the same machine can serve different models
   without script edits.

### Library renames

3. `git mv libs/ollama-config.lua libs/inference-server-config.lua`.
   Inside the file, search-and-replace the public-API names:
   - `ollama_config` -> `inference_config` in the doc comments
   - The doc comments themselves refer to "Ollama" by name in many
     places; keep the references where they describe historical
     context but replace forward-looking mentions.
4. `git mv src/ollama-manager.lua src/embedding-server-manager.lua`.
   The functions in this module ping the server, check liveness,
   and warm up the model. The implementation will change for
   llama.cpp (different endpoints) but the module-level API
   (`ensure_ready`, `test_embedding`) stays.

### Config schema changes

5. In `config.lua`:
   - Rename the `ollama_servers = {...}` block to
     `inference_servers = {...}`. Inside each entry, keep
     `name`, `host`, `port`, `model`, `available_models`,
     `description`. Add a `model_path` field that points at the
     GGUF on disk (so the start script can find it).
   - Rename `default_ollama_server` -> `default_inference_server`.
   - The model strings change from Ollama tags (e.g.
     `qwen3-embedding:4b`, `nomic-embed-text:v1.5`) to GGUF
     basenames (e.g. `qwen3-embedding-4b.Q4_K_M.gguf`,
     `nomic-embed-text-v1.5.Q4_K_M.gguf`). The sanitization rule
     in `utils.embeddings_dir()` still works for the new strings.
6. Update CLI flag naming:
   - `run.sh`: rename the `--ollama=<name>` flag to `--server=<name>`
     and the `OLLAMA_SERVER` shell variable to `INFERENCE_SERVER`.
   - Update the help text and the menu items in the TUI driver.
   - `generate-embeddings.sh` similarly.

### Endpoint changes

7. In `libs/inference-server-config.lua` and every consumer that
   builds an HTTP request:
   - Change request path from `/api/embeddings` / `/api/embed` to
     `/v1/embeddings` (OpenAI-compatible endpoint that llama.cpp
     serves).
   - Change request body from `{"model": "...", "prompt": "..."}` to
     `{"model": "...", "input": "..."}`. The OpenAI body uses
     `input`; Ollama used `prompt`.
   - Change response parsing from `parsed.embedding` (Ollama) to
     `parsed.data[1].embedding` (OpenAI). The OpenAI shape
     supports batched inputs and returns a `data` array.
8. Update the liveness check from `/api/tags` to `/v1/models` (the
   OpenAI-compatible equivalent that llama.cpp also implements).

### Search-and-replace methodology

The search/replace is mechanical but each match needs visual review
because some references are intentional historical context (e.g.
the words "Ollama" in comments explaining what was migrated FROM)
and should NOT be rewritten.

Use the following grep patterns to enumerate each class of match,
then handle them in batches:

```bash
# All Ollama mentions, case-insensitive
grep -rln -i "ollama" src/ libs/ scripts/ config.lua run.sh generate-embeddings.sh

# Module require calls that need renaming
grep -rn 'require("ollama-config")\|require("ollama-manager")' src/ libs/ scripts/

# Symbol references that need renaming
grep -rn 'ollama_config\b\|ollama_manager\b' src/ libs/ scripts/

# Config field names
grep -rn 'ollama_servers\|default_ollama_server' src/ libs/ config.lua

# CLI flag and shell variable
grep -rn '\-\-ollama\b\|OLLAMA_SERVER\b\|OLLAMA_HOST\b' src/ libs/ scripts/ run.sh generate-embeddings.sh

# API endpoint paths
grep -rn '/api/embeddings\|/api/embed\|/api/tags' src/ libs/ scripts/

# Request body fields
grep -rn '"prompt":' src/ libs/ scripts/
```

For the actual renames, the safest path is one search-and-replace
per pattern, with a diff review between each, because:

- `ollama_config` is used as both a variable name AND a function
  table reference, so a blanket text replace would mangle some
  contexts.
- API path changes need request-body changes in the same edit,
  otherwise the new server returns 4xx errors that look like a
  network problem.
- The string `ollama` appears in commit messages and historical
  comments where it should remain.

A reasonable batching:

1. Library rename via `git mv` (so the history is preserved)
2. All `require("ollama-config")` -> `require("inference-server-config")`
3. All `ollama_config` symbol references -> `inference_config`
4. Config schema changes in `config.lua` and all consumers
5. CLI flag and shell variable renames
6. Endpoint URL and request body changes (these go together as
   one atomic batch — they cannot be split without breaking the
   API call)
7. Doc-comment cleanup pass — remove the now-irrelevant Ollama
   mentions, keep the historical ones that describe what was
   migrated from.

### Verification

9. After each batch above, run the project's standard sanity check
   (whatever exists at the time of the migration) and verify the
   pipeline still parses. The Lua modules should all `require()`
   cleanly; the run.sh help text should not mention "ollama";
   the config-loader should not error out.
10. End-to-end test: generate a small embedding batch (e.g. 100
    poems) end-to-end against the new llama.cpp server. Compare the
    resulting `embeddings.json` against what Ollama produced for the
    same poems with the same model. The vectors will not be
    bit-identical because of nondeterministic floating-point
    accumulation order in the inference runtime, but cosine
    similarity between corresponding vectors should be > 0.999
    (essentially the same vector up to numerical noise).

## Related Documents

- This issue exists because of cumulative pain points around
  Ollama documented in earlier sessions: silent fallbacks to wrong
  servers, slow embedding throughput, and the fact that the project
  has built its own server-selection / model-resolution layer on
  top of Ollama's already-thin abstraction. Removing one of the two
  abstractions seems healthy.
- The model strings the new path will use (GGUF basenames) interact
  with `utils.embeddings_dir()` which sanitizes the name into a
  filesystem-safe directory. The sanitization is already permissive
  enough to handle dots and hyphens, so no changes there.
- The build script needs to honor the project's convention of a
  hardcoded `${DIR}` at the top with optional first-arg override.

## Risks

- The Ollama abstraction is well-exercised in the current pipeline;
  llama.cpp's server is well-known but the project has not yet run
  it under the same load. Embedding 8,000+ poems sequentially via
  HTTP requests could surface bottlenecks (connection pooling,
  keep-alive, etc.) that did not manifest under Ollama. The
  embedding step should be re-benchmarked after the migration.
- llama.cpp's CUDA build sometimes lags behind upstream CUDA
  releases. The build script should pin a specific llama.cpp
  commit hash rather than tracking main, so a future upstream
  break does not silently break the project's build.
- The model name change (GGUF filenames vs Ollama tags) means the
  on-disk embeddings cache path also changes (because
  `utils.embeddings_dir()` derives the directory from the model
  name). Existing FP16-cached embeddings will become unreachable
  unless the user manually renames the directory. Either accept
  this as a one-time regen cost, or add a migration helper.
- Operationally, llama.cpp's server has different memory-usage
  characteristics than Ollama's. The 1080 Ti has 11 GB of VRAM;
  the embedding models we use are small (well under 1 GB), but if
  the project ever adds a generation model alongside the embedder,
  the budget gets tighter.

## Expected Outcome

- Ollama is fully removed from the codebase. `grep -rln -i ollama
  src/ libs/ scripts/ config.lua run.sh` returns zero results
  outside historical comments.
- A single llama.cpp `llama-server` instance, started by
  `scripts/start-llamacpp-server.sh`, serves embedding requests
  for the entire pipeline.
- Build is reproducible via `scripts/build-deps.sh` from a clean
  clone, with a pinned llama.cpp commit hash and a deterministic
  model download.
- Configuration shape is preserved in spirit (multi-server support,
  default selection, CLI override) but with new vocabulary.
- Embedding throughput is at least as fast as it was under Ollama
  for the same model; ideally faster for short prompts because
  the model is loaded once at server start instead of warmed on
  each model switch.
- One less third-party daemon to install and keep running.

