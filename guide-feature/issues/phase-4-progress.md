# Phase 4 Progress — The turn

## Goals
The endpoints file in the project root and choosing endpoints while
running, the llama.cpp client, the turn's prompt, and asking until the
edited canvas fits, with compiler-style reports. Ends with three real turns
per version on kuvalu's llama.cpp server.
(`docs/roadmap.md`, phase 4)

Counts of done and open issues:
`/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/guide-feature -m`

## Completed Issues
- **401b, the client and the endpoints file** (2026-11-05):
  - `libs/llama-chat-client.lua`, this project's copy of delta-version's
    client, with an endpoint record per call and an embedding call.
  - `libs/dkjson.lua`, and `scripts/refresh-vendored` to copy both again
    from their upstreams.
  - `endpoints` in the project root, with proposed ports.
  - `src/046-model-caller.lua`, which reads `endpoints` again for every
    role's every call, and names the endpoint in every failure.
  - Tested against a stand-in llama.cpp server on 127.0.0.1
    (`src/047-stand-in-llama.lua`). The run against 401a's real servers is
    left for the owner's machine.
