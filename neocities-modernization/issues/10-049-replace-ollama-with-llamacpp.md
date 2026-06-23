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

The build-side plumbing for the replacement has landed:
`scripts/build-deps.sh` installs the CUDA toolkit into `libs/cuda/`
(either by syncing Ollama's bundled CUDA 12.6 or by downloading the
NVIDIA 12.9 runfile), clones and builds llama.cpp at a pinned tag
with CUDA + the GPU's exact compute capability, downloads the GGUF
model, and smoke-tests `llama-server`'s `/v1/embeddings` endpoint.
The runtime Lua and shell callers still talk to Ollama — they have
not yet been migrated.

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

1. `scripts/build-deps.sh` is the single entry point that prepares
   everything the runtime needs. Hard-code the canonical project DIR
   at the top with the option to override via the first positional
   argument, per the project convention. The script does, in order:

   **a. Prerequisite check.** Verifies basic build tools (git, cmake,
   make, curl, gcc, g++) and the NVIDIA driver (via `nvidia-smi`)
   are present. A missing nvcc is NOT fatal — the script will
   install one. A missing kernel driver IS fatal, because no
   userspace install can recover from that.

   **b. CUDA toolkit install into `libs/cuda/`.** The project owns
   its own CUDA toolkit copy under `libs/`, independent of whatever
   the system's `/usr/local/cuda` points at. There is exactly one
   install path: download the CUDA 12.9 runfile installer from NVIDIA
   into `tmp/downloads/`, then run
   `sh ... --silent --toolkit --toolkitpath=$DIR/libs/cuda
   --no-opengl-libs --no-man-page --tmpdir=$DIR/tmp` with stdout+stderr
   captured to `$DIR/tmp/cuda-installer-output.log`. The `--toolkitpath`
   flag makes the runfile write its toolkit directly into the
   user-owned `libs/cuda/`, so no sudo is required and nothing lands
   in `/usr/local`. NOTE: the CUDA 12.9 installer has no flag to
   redirect its internal log (which writes to `/var/log/cuda-installer.log`
   if writable, silently drops it if not) — hence the shell-level
   stdout+stderr capture instead of `--installer-log-file=` (which
   existed in CUDA 11.x but was dropped in 12.x).
   `libs/cuda/` is wiped before each install so a stale toolkit cannot
   coexist with the new one. If `libs/cuda/bin/nvcc` already reports a
   version starting with `12.9`, the install is skipped entirely.

   Ollama's bundled CUDA 12.6 was tried as a download-free alternative
   and removed: its `.so` files were built without Pascal in their
   arch list, so the resulting binaries do not actually run on a 1080
   Ti even though the toolkit metadata says they should. The script
   now has exactly one supported CUDA path.

   The CUDA version pinning is deliberate: CUDA 13.0+ drops Pascal
   (sm_61, the 1080 Ti) entirely, so the project is locked to the
   12.x line. We do NOT use the distro package manager — most rolling
   distros (Void, Arch) ship CUDA versions that lag NVIDIA's official
   release, and the package-manager path makes it hard to keep a
   project-owned copy at `libs/cuda/`.

   **glibc 2.40+ compatibility patch.** CUDA 12.9.0's
   `include/crt/math_functions.h` declares `sinpi`, `sinpif`, `cospi`,
   and `cospif` without `noexcept(true)`. glibc 2.40+ declares the
   same functions via `__MATHCALL_VEC` *with* `noexcept(true)`. nvcc
   rejects the exception-specification mismatch, breaking every CUDA
   compilation on hosts with modern glibc. CUDA 12.9.1+ patches this
   upstream; we patch the 12.9.0 headers in place via
   `patch_cuda_headers()` after `install_cuda_runfile()` succeeds.
   The patch is idempotent (gated on `/noexcept/!`) so re-running is
   safe. If the script is ever bumped to 12.9.1 the patch will become
   a no-op naturally.

   **c. llama.cpp clone and build (in RAM-backed `tmp/`).** Clones
   https://github.com/ggml-org/llama.cpp at a pinned tag (currently
   `b4404`) into `$DIR/tmp/llamacpp-src/` (NOT into `libs/`). The
   build dir is `tmp/llamacpp-src/build/` — peaks at 1–3 GB of
   intermediate object files, all in tmpfs RAM so disk wear is
   negligible. Configures cmake with:
   - `-DGGML_CUDA=ON -DGGML_NATIVE=ON`
   - `-DCUDAToolkit_ROOT=$DIR/libs/cuda` (hermetic — does not touch
     the host PATH).
   - `-DCMAKE_CUDA_ARCHITECTURES=$ARCH` where `$ARCH` is the digits
     of the local GPU's compute capability from `nvidia-smi` (e.g.
     `61` for the 1080 Ti). This both shortens build time and ensures
     Pascal stays in the compiled arch list — recent CUDA defaults
     silently drop it.
   - `-DCMAKE_CUDA_FLAGS=-allow-unsupported-compiler` when the host
     gcc is newer than the installed CUDA's supported max. The script
     looks up the max from a small table indexed by CUDA 12.6 / 12.9.
     With the new default (12.9 on gcc 14), this is not added.
   - `-DCMAKE_INSTALL_PREFIX=$DIR/libs/llama.cpp` so the later
     install step lays artifacts in the disk-backed project tree.
   - `-DCMAKE_INSTALL_RPATH='$ORIGIN/../lib'` so the installed
     `llama-server` finds its sibling `.so` files via RPATH without
     needing LD_LIBRARY_PATH set at run time.

   **d. Install artifacts to `libs/llama.cpp/`.** After a successful
   build, `cmake --install` copies only the finished products (`bin/`,
   `lib/`, `include/`) from `tmp/llamacpp-src/build/` into
   `$DIR/libs/llama.cpp/`. The source tree and build tree in tmp/ can
   be wiped after this without affecting the project's ability to run
   the server. If `libs/llama.cpp/.git` exists (the old layout where
   source lived under `libs/`), the script bails with a clear message
   asking the operator to `--clean` or manually delete the directory.

   **e. Model download.** Pulls the configured GGUF embedding model
   from HuggingFace into `$DIR/assets/models/<model>.gguf`. The
   model basename matches what `config.lua` expects.

   **f. Smoke test.** Launches the installed
   `libs/llama.cpp/bin/llama-server --embedding` on a non-default
   port (18080), waits for `/health` to respond, sends one
   `/v1/embeddings` request, and verifies the response body contains
   an `"embedding"` key. `LD_LIBRARY_PATH` is set to `libs/cuda/lib64`
   for the test run so dlopen can find the CUDA runtime. The binary's
   own RPATH already covers `libs/llama.cpp/lib/`, so we don't need
   to add that.

   CLI flags: `--clean`, `--no-model`, `--skip-cuda`, `--force-cuda`,
   `--help`. Env var: `BUILD_JOBS=N` caps parallel cmake build jobs
   (default 8, sized for thermal headroom on a summer-warm host).

2. Write `scripts/start-llamacpp-server.sh` mirroring the shape of
   `start-ollama-cuda.sh`. Read host, port, and model path from
   `config.lua` so the same machine can serve different models
   without script edits. The start script must export
   `LD_LIBRARY_PATH=$DIR/libs/cuda/lib64:$LD_LIBRARY_PATH` and
   `PATH=$DIR/libs/cuda/bin:$PATH` before launching the server, so
   the project-local CUDA runtime is found regardless of whether the
   operator's shell rc has been updated.

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

9. **Static checks** (run after each rename batch — cheap, must always pass):

   ```bash
   # All touched Lua files compile cleanly
   for f in libs/inference-server-config.lua libs/fuzzy-computing.lua \
            libs/triangular-similarity-access.lua libs/utils.lua \
            src/embedding-server-manager.lua src/main.lua \
            src/centroid-generator.lua src/generate-word-pages.lua \
            src/semantic-color-calculator.lua src/similarity-engine.lua \
            src/centroid-html-generator.lua src/flat-html-generator.lua \
            src/html-generator/similarity-engine.lua \
            libs/vulkan-compute/lua/vk_similarity.lua config.lua; do
       luajit -bl "$f" /dev/null 2>&1 \
           && echo "  ok   $f" \
           || echo "  FAIL $f"
   done

   # All touched shell scripts parse cleanly
   for f in run.sh generate-embeddings.sh demos/1-demo.sh phase-demo.sh \
            scripts/build-deps.sh scripts/start-llamacpp-server.sh; do
       bash -n "$f" && echo "  ok   $f" || echo "  FAIL $f"
   done

   # Config resolves end-to-end through the renamed module
   luajit -e "
       package.path = './libs/?.lua;' .. package.path
       local inference = require('inference-server-config')
       inference.set_project_root('.')
       local s = inference.get_default_server()
       print('default server: ' .. s.name)
       print('  url:        ' .. inference.build_host_url(s))
       print('  model:      ' .. s.model)
       print('  model_path: ' .. (s.model_path or '(MISSING)'))
   "
   ```

   Expected: every file bytecode/syntax-clean, default server resolves to
   the operator's local llama.cpp instance with a real `model_path`.

10. **Live end-to-end** (requires `scripts/build-deps.sh` to have produced
    a working install first):

    ```bash
    # 1. Build the CUDA toolkit + llama.cpp + download the GGUF model.
    #    This is the slow step; only needs to run once.
    ./scripts/build-deps.sh

    # 2. Launch the llama.cpp embedding server.
    ./scripts/start-llamacpp-server.sh
    # The script polls /health until ready; success ends with
    # "🚀 Ready for embedding requests at http://HOST:PORT/v1/embeddings"

    # 3. Generate embeddings for a small batch of poems and compare
    #    against the Ollama-era cache. Replace 100 with whatever batch
    #    size makes sense.
    ./generate-embeddings.sh --incremental --dir=/tmp/llamacpp-verify

    # 4. Compare with cosine similarity. The vectors will not be
    #    bit-identical because floating-point accumulation order in
    #    deep-network forward passes is nondeterministic across
    #    inference engines, but cosine similarity between corresponding
    #    vectors should be > 0.999 (essentially the same vector up to
    #    numerical noise).
    luajit -e "
        package.path = './libs/?.lua;' .. package.path
        local fuzzy = require('fuzzy-computing')
        -- Load both embeddings.json files, walk corresponding poems,
        -- print min/mean/max cosine similarity across the batch.
        -- See test fixtures if a ready-made comparator is needed.
    "
    ```

    A pass = mean cosine similarity > 0.999, min > 0.995 (one outlier is
    OK; many outliers means the model strings or prompt prefixes drifted
    between the two runs).

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
  releases. `scripts/build-deps.sh` pins llama.cpp to the `b4404`
  tag rather than tracking master, so a future upstream break does
  not silently break the project's build. Bump the constant after
  testing.
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

