# 401a — Our own llama.cpp servers

phase 4, the turn. Sub-issue of 401.

## Current behavior

guide-feature has no language-model server. words-pdf has a llama.cpp git
clone at `/home/ritz/programming/ai-stuff/words-pdf/libs/llama.cpp` (last
commit `f449e0553`, 2026-06-20) with a CUDA build, and its own build and
start scripts. Those are words-pdf's and are not used here.

## Intended behavior

- **`libs/llama.cpp/`**: a git clone whose `origin` is words-pdf's local
  checkout, so `git -C libs/llama.cpp pull` updates it from there
  (`docs/vendored-code.md`). The monorepo ignores the folder and records the
  commit in `libs/llama.cpp.upstream`.
- **`scripts/build-llama`**: builds the server for kuvalu's GTX 1080 Ti
  (CUDA) into `libs/llama.cpp/build/`. It is written for this project after
  reading words-pdf's build script, not by calling it.
- **Models**: one chat model and one embedding model, file paths recorded
  in `endpoints` as `NAME.model`. Which models is decided with the owner;
  words-pdf's Qwen3-8B is the known working size for this GPU.
- **Ports**: one per server, chosen away from ports other projects use
  (checked with `ss -ltn` and by searching the monorepo for the number), and
  recorded in `endpoints` as `NAME.port`.
- **`scripts/start-servers`** and **`scripts/stop-servers`**, as described
  in `docs/endpoints.md`, "The servers". Start waits until every server
  answers `/v1/models` and fails loudly if one does not. Stop leaves nothing
  running, so the GPU is free whenever guide-feature is not in use.
- The chat server is started with its chat templates switched on
  (`--jinja`), so llama.cpp's tool calls are available to the look tool,
  unless the owner decides otherwise (`docs/open-questions.md`, 11).

## Suggested implementation steps

1. Clone, record the upstream, add the folder to the monorepo's ignore list.
2. Read words-pdf's build and start scripts for the flags that work on this
   GPU. Write this project's own.
3. Choose models and ports with the owner. Fill in `endpoints`.
4. Test: start, ask each server for its models, stop, and check that the
   ports are closed and no server process is left.

## Related documents

- `docs/endpoints.md`
- `docs/vendored-code.md`

## Open questions

- Which chat model and which embedding model?
- Tool calls through `--jinja`, or a plain line in the reply?
  (`docs/open-questions.md`, 11)

## Blocked by

None.

## Blocks

401, 401b.
