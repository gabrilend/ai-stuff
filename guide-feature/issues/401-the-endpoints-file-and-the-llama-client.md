# 401 — The endpoints file and the llama.cpp client

phase 4, the turn

## Current behavior

Nothing exists in this project. kuvalu already has:

- a llama.cpp server set up by words-pdf (Qwen3-8B on
  `192.168.1.100:20166`, started by `words-pdf/scripts/start-llamacpp-server.sh`).
  It was not answering when checked on 2026-10-21;
- delta-version's reusable client,
  `delta-version/scripts/libs/llama-chat-client.lua` (chat, exact token
  counts, reachability; needs `curl` and the shared `dkjson`);
- words-pdf's `libs/fuzzy-computing.lua`, which calls `/v1/embeddings`.

## Intended behavior

The owner: "let's implement this using llama.cpp. We can run on kuvalu for
now, but make sure there's a config file in the project root that allows us
to set multiple endpoints that can be selected from at runtime."

- **`endpoints`** in the project root, in the format of `docs/endpoints.md`,
  first listing kuvalu's chat server and an embedding server, with every
  `use.` role pointed at them.
- **The endpoints reader**: reads the file with the settings reader (101),
  checks every `use.` line names an endpoint of the right kind, and answers
  "which endpoint does this role use". Called at the start of every turn,
  never cached across turns.
- **The model caller**: a thin layer over delta-version's client that takes
  an endpoint record, so every role reaches its own endpoint. Calls are chat,
  token count, embedding and reachability. A failure is an error naming the
  endpoint and its address. There is no fallback to another endpoint.

## Suggested implementation steps

1. The `endpoints` file, and its reader.
2. The model caller, reusing delta-version's client rather than copying it.
   If the client needs a change (an embedding call, a per-call endpoint), that
   change is made in delta-version through an issue there.
3. Tests against a running server: a chat reply, a token count, an
   embedding, a stopped server reported as unreachable.

## Related documents

- `docs/endpoints.md`

## Blocked by

None.

## Blocks

402, 404, 502, 601, 703.
