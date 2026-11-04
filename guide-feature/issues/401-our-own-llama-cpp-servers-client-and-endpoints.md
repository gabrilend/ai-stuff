# 401 — Our own llama.cpp servers, client and endpoints file

phase 4, the turn

## Current behavior

Nothing exists in this project. Other projects on kuvalu have their own
llama.cpp setups (words-pdf: a CUDA build in `words-pdf/libs/llama.cpp`, a
server on port 20166 that was not answering on 2026-10-21; delta-version: a
Lua client). The owner's rule is that this project uses none of them
directly: "We will be implementing our own server for this project, no
cross-project interrequirements are encouraged."

## Intended behavior

The owner: "let's implement this using llama.cpp. We can run on kuvalu for
now, but make sure there's a config file in the project root that allows us
to set multiple endpoints that can be selected from at runtime."

guide-feature has its own llama.cpp, its own servers, its own client, and
the `endpoints` file that names them (`docs/endpoints.md`). Reused code is
copied in from a local upstream (`docs/vendored-code.md`).

This issue holds two separate pieces of work, a build-and-run piece and a
Lua piece, so it is split:

| ID | Name | Dependencies | Description |
|---|---|---|---|
| 401a | our-own-llama-cpp-servers | None | clone llama.cpp from words-pdf's local checkout as upstream, build it for kuvalu's GPU, choose this project's ports and models, start and stop scripts |
| 401b | the-client-and-the-endpoints-file | 401a | copy in delta-version's client and dkjson, add an embedding call, the `endpoints` file and its reader, the per-endpoint model caller |

Order: 401a (foundation) → 401b (needs a running server to test against).

## Suggested implementation steps

See 401a and 401b.

## Related documents

- `docs/endpoints.md`
- `docs/vendored-code.md`

## Blocked by

401a, 401b.

## Blocks

402, 404, 502, 601, 703.
