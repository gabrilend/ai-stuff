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

## Decisions (2026-11-05)

Built ahead of 401a, against a stand-in server, because 401a's servers
and models live on the owner's machine.

1. **The tests use a stand-in llama.cpp server, not 401a's.**
   `src/047-stand-in-llama.lua` answers llama-server's four routes in its
   shapes (`/v1/models`, `/v1/chat/completions`, `/tokenize`,
   `/v1/embeddings`), including the 501 a chat server gives for embeddings
   and an embedding server for chat. It listens on 127.0.0.1 only, on a
   port the system gives. Step 4's run against the real servers is left
   for the owner's machine.
2. **No configured address and no environment override in the client.**
   delta-version's `configure()` and `INFERENCE_CHAT_HOST` are gone from
   the copy. Every call is handed its endpoint record, so nothing outside
   `endpoints` can re-point a role. A hidden override would let a canvas
   look as if one model wrote it when another did.
3. **dkjson is found beside the client**, from the client's own path, not
   through `AISTUFF_ROOT`, so nothing is loaded from another project.
4. **A failed call is a Lua error**, starting with the endpoint's name and
   address. A turn that meets one fails, and the turn runner already counts
   and logs failed turns (304). There is no fallback.
5. **Every endpoint a role uses needs a `timeout`.** It is checked by the
   model caller, not the reader, so 101's reader keeps accepting an
   endpoint no role uses yet. Nothing has a default in code.
6. **Endpoints with a `key-file` are refused until 402.** A request sent
   without its key would only be refused by the provider, later and less
   clearly.
7. **The model name sent is the endpoint's name.** llama-server ignores it,
   and the API wants a value. An outside provider that needs a real model
   name is 402's to handle.
8. **Either kind of endpoint may count tokens.** Each counts with its own
   model's tokenizer. Chat on an embedding endpoint, and an embedding on a
   chat one, are refused before anything is sent.
9. **A reply other than 2xx is an error even without an error body**, a
   case the upstream client passed on as a parse result.
10. **`chat` also returns the token usage and the seconds taken**, for the
    turn's counts (404).
11. **`endpoints` proposes ports 21223 (chat) and 21224 (embedding)** on
    the kuvalu address the docs already use. No file in the monorepo uses
    either as a port. They are written as proposals: 401a confirms them
    with `ss -ltn` on kuvalu and adds each `NAME.model` once the models
    are chosen with the owner.
12. **`scripts/refresh-vendored` merges, it does not overwrite, a copy with
    changes of its own.** It takes the upstream as committed (not its
    working tree), so the note's commit names exactly what was copied. A
    copy with `changes: none` is replaced. A changed copy is merged three
    ways with `git merge-file`. A conflict is left beside it as
    `libs/<file>.merge`, with the copy and its note untouched.

## Implementation notes (2026-11-05)

- `libs/llama-chat-client.lua` and `libs/dkjson.lua`, each beside its
  `.upstream` note; `scripts/refresh-vendored`.
- `endpoints` in the project root.
- `src/046-model-caller.lua`, the endpoints reader's use and the model
  caller; the reader itself is 101's `read_endpoints`.
- `src/047-stand-in-llama.lua`, the stand-in server, test code only.
- `src/048-test-model-caller.lua`: 63 pass. It covers the issue's five
  cases, the file read again on every call, a timeout, a server error, the
  command line, this project's own `endpoints`, and refresh-vendored
  against a throwaway upstream repository.
- Mutation checks, all 14 caught: no UTF-8 cleaning, embeddings by place
  (caught once the stand-in lists them last first), no curl time limit,
  the endpoints cached, no timeout, key or kind check, errors without the
  endpoint's name, no usage, and five on refresh-vendored.
- `docs/endpoints.md`, `docs/vendored-code.md`, `libs/README`.
  `.file-index-counter` is at 048.

**Needs the owner's machine:**
- 401a's servers running on kuvalu.
- This issue's step 4 against them: start them, point a scratch
  `endpoints` at them, and call `chat`, `count_tokens`, `embed` and
  `reachable` (or the client's `--ping`, `--tokens`, `--prompt` and
  `--embed`).
- The ports confirmed and the model files chosen, written into
  `endpoints`.
