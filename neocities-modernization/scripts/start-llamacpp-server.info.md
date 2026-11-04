# start-llamacpp-server.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in scripts/start-llamacpp-server.sh: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
scripts/start-llamacpp-server.sh
Launches the project-local llama.cpp embedding server. Reads which server
(host, port, model file) to launch from config.lua's inference_servers
via libs/inference-server-config.lua, sets up the CUDA runtime on
LD_LIBRARY_PATH so the binary's dlopen of libcudart succeeds, then
starts llama-server with --embedding so the OpenAI-compatible
/v1/embeddings endpoint is active. Verifies the server is responsive
via /health before declaring success.

Usage:
  ./scripts/start-llamacpp-server.sh                # Default server from config.lua
  ./scripts/start-llamacpp-server.sh --server=NAME  # Specific server entry
  ./scripts/start-llamacpp-server.sh /custom/dir    # Override project DIR
  ./scripts/start-llamacpp-server.sh --help         # Show this message

Replaces the old Ollama launcher (removed 2026-10-22) as the embedding-backend launcher
per issue 10-049. The on-disk binary at libs/llama.cpp/bin/llama-server
is produced by scripts/build-deps.sh; if it is missing, run that script
first.
```

## Functions

### `parse_arguments()`

```
Recognized flags:
  --server=NAME : override the default_inference_server from config
  --model=NAME  : required; the model to serve, one of that server's
                  available_models (loads its GGUF). There is no default.
  --dir PATH    : override the project DIR; a stray word stops the script
                  (libs/project-dir.sh, Issue 10-076; it used to be any
                  bare word)
```

### `resolve_server_config()`

```
Asks libs/inference-server-config.lua to resolve the chosen server (default
or --server=NAME override) and prints to stdout, one per line: host, port,
model_path (relative to DIR), the model identifier, the model's
vision_projector (relative to DIR, or "-" for a model without one), and then
each word of the server's launch_flags (zero or more lines). Errors from the
module (typoed --server, missing default) propagate to stderr verbatim.
Running the module in a subprocess keeps the parent shell free of any
stray Lua state and lets us capture exactly the fields we want.
```

### `setup_env()`

```
Prepend libs/cuda to PATH and LD_LIBRARY_PATH so the llama-server binary
finds nvcc tools (when invoked) and libcudart at dlopen time. The binary's
own RPATH covers libs/llama.cpp/lib (built into the binary by build-deps.sh
via -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib'), so we do not need to add that
directory explicitly.

GGML_CUDA_FORCE_MMQ was tried 2026-06-20 and reverted. The hard-freeze
symptom predated this flag, so MMQ wasn't the cause; forcing MMQ might
just be picking a different-but-also-buggy CUDA kernel path on Pascal.
Removed to use the default kernel selection (cuBLAS where applicable).
```

### `already_running()`

```
Returns 0 if some server is already healthy at HOST:PORT — meaning we
should not try to start a second one. Returns non-zero otherwise.
```

### `verify_artifacts()`

```
Sanity-check that the things we need to actually run llama-server exist
on disk before launching. Failing here with a clear "run build-deps.sh"
message is friendlier than letting the operator debug a missing-binary
error or a missing-model crash from the server's log.
```

### `launch_server()`

```
Start llama-server in the background with --embedding so the embedding
endpoints are active. Output goes to LOG_FILE in the RAM-backed tmp/
directory; SERVER_PID is captured so the operator can stop it cleanly.
```

### `wait_for_ready()`

```
Poll /health until the server responds or we hit the timeout. Returns 0
on success, 1 on timeout. Using /health is the lightest "are you alive"
probe the server exposes; /v1/models would also work but takes slightly
longer to respond because it walks the loaded model list.
```

### `main()`
(No comment above it in the source.)
