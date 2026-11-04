# embedding-server-manager.info.md

<!-- made by scripts/write-info-notes (Issue 10-076), from the comments in src/embedding-server-manager.lua: its header and the comment above each function. To refresh it, delete this file and run the tool again; to write the notes by hand, replace this line. -->

## What it is, and how to run it

```
Issue 10-049: Embedding-server manager. Originally written for Ollama
(10-005); reimplemented for llama.cpp. Provides liveness checks against
the configured inference server, can launch start-llamacpp-server.sh
when the server is down, and runs an end-to-end test embedding request.

Public API (preserved across the migration so call sites do not need
to change shape):
  M.ensure_ready()           — return the endpoint URL once the server is up
  M.test_embedding(ep, model) — send one /v1/embeddings request, verify shape

The big shape changes from the Ollama era:
  - /api/tags        → /v1/models       (OpenAI-compatible liveness)
  - /api/embeddings  → /v1/embeddings   (OpenAI-compatible inference)
  - "prompt" body    → "input" body     (OpenAI request shape)
  - response.embedding → response.data[1].embedding   (OpenAI response shape)
  - "ollama pull"    → (removed)        (llama.cpp has the model on disk
                                         already; nothing to pull)
  - "ollama serve"   → delegate to scripts/start-llamacpp-server.sh

--help: print the header above and exit, when run as a program (libs/script-help.lua)
```

## External functions (what other programs can call)

### `M.ensure_ready()`

```
Resolves the configured inference server, checks if it's running, starts
it if not. Returns the endpoint URL on success, nil on failure. The
public name dropped the "ollama" prefix in 10-049; callers update their
call site in the same atomic batch as the require rename.
```

### `M.test_embedding(endpoint, model)`

```
Sends a single test embedding request to /v1/embeddings (OpenAI shape)
and verifies the response body contains a "data" array with an
"embedding" key. We don't strictly validate the vector dimensions —
that's the consumer's job — but the substring check catches the
obvious "server started but doesn't actually serve embeddings" failure.
```

### `M.main(interactive_mode)`

```
Interactive entry point for running the manager standalone.
```

## Inside (local to the file)

### `setup_dir_path(provided_dir)`
(No comment above it in the source.)

### `is_server_running(endpoint)`

```
Pings /v1/models to verify the server is alive. /v1/models is llama.cpp's
OpenAI-compatible "what's loaded" endpoint — returns 200 with a JSON list
of one model when the server is healthy. We don't parse the list (the
consumer's job); exit code 0 from curl is enough to say "alive".
```

### `start_llamacpp_service()`

```
Invokes scripts/start-llamacpp-server.sh, which handles its own env setup
(libs/cuda on LD_LIBRARY_PATH), config resolution, and liveness wait.
Returning exit code 0 from the script means the server is up; we don't
need to wait again here.
```
