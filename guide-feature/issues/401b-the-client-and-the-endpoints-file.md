# 401b — The client and the endpoints file

phase 4, the turn. Sub-issue of 401.

## Current behavior

Our own servers exist (401a). Nothing in this project talks to them.

## Intended behavior

- **`libs/llama-chat-client.lua`**: a copy of delta-version's client
  (`delta-version/scripts/libs/llama-chat-client.lua`), with
  `libs/llama-chat-client.lua.upstream` naming the source and its commit.
  This project's changes are made in the copy: an embedding call
  (`/v1/embeddings`), and taking an endpoint record per call rather than one
  configured address, so each role reaches its own endpoint.
- **`libs/dkjson.lua`**: copied the same way, from
  `/home/ritz/programming/ai-stuff/libs/lua/`.
- **`scripts/refresh-vendored`**: copies each single-file copy from its
  upstream again, shows the differences, and updates the `.upstream` note
  (`docs/vendored-code.md`).
- **`endpoints`** in the project root (`docs/endpoints.md`), listing the
  servers from 401a, with every `use.` role pointed at them.
- **The endpoints reader**: reads the file with the settings reader (101),
  checks that every `use.` line names an endpoint of the right kind, and
  answers "which endpoint does this role use". It is called at the start of
  every turn and never cached across turns.
- **The model caller**: chat, token count, embedding and reachability calls
  against an endpoint record. A failure is an error naming the endpoint and
  its address. It never falls back to another endpoint.

## Suggested implementation steps

1. Copy the client and dkjson in, with their `.upstream` notes. Write
   `scripts/refresh-vendored`.
2. The changes to the copied client.
3. `endpoints`, its reader, the model caller.
4. Tests against 401a's servers: a chat reply, a token count, an embedding,
   a stopped server reported as unreachable, a `use.` line naming an endpoint
   that does not exist.

## Related documents

- `docs/endpoints.md`
- `docs/vendored-code.md`

## Blocked by

401a.

## Blocks

401.
