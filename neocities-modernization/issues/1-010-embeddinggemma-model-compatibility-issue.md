# Issue 1-010: EmbeddingGemma Model Compatibility

## Status
- **Phase**: 1
- **Status**: Reopened (2026-10-07) — EmbeddingGemma 2 to be installed and tested
- **First opened**: 2025-11-02 · **First closed**: 2025-12-14 · **Reopened**: 2026-10-07

## Current Behavior

The project embeds poems with a local llama.cpp server (Issue 10-049). Three
GGUF models are registered under the `local` server's list of available models
in `config.lua`, each with its own file in `assets/models/` and its own task
prefix:

- `nomic-embed-text-v1.5` — prefix `"clustering: "`
- `mxbai-embed-large-v1` — no prefix
- `embeddinggemma-300m` (EmbeddingGemma 1, 308M params, 768 dims, 2K context)
  — prefix `"task: clustering | query: "`
- `embeddinggemma-2` — registered (see below), prefix `"task: clustering | query: "`

EmbeddingGemma 2 is downloaded and registered but not yet run. The file is
`assets/models/embeddinggemma-2-Q8_0.gguf` (309,855,456 bytes, sha256
`2188ac1deca4b77dffefd603c2776a9d76d9d74ec01841392982ebb840b09135`, matching
the Hugging Face listing). It is the fourth entry in the `local` server's model
list and in the similarity engine's model table. The build script's llama.cpp
pin is raised to `b11476`; the build itself has not been run (the owner runs
it, to watch). Google released the model on 2026-10-06:
740M parameters in total (a 270M text model plus vision and audio encoders),
768-dimension output, 8K-token context, built on Gemma 4, Apache 2.0. Official
GGUFs are at `ggml-org/embeddinggemma-2-GGUF` (BF16 and Q8_0, with separate
vision/audio projector files that this project does not need).

llama.cpp is compiled from source by `scripts/build-deps.sh`, which clones a
pinned release tag into the RAM-backed `tmp/llamacpp-src/` and installs the
binaries into `libs/llama.cpp/`. The pin is `b9842` (installed 2026-06-29).
Support for the new architecture arrived upstream in commit `4fbc76dec5`
("model: support embeddinggemma2 (text+vision+audio)", merged 2026-10-06);
the first release tag that contains it is **`b11454`** (checked against
GitHub's compare view). The previous pin, `b9842`, cannot load the file.

The model card (google/embeddinggemma-2) keeps version 1's symmetric
clustering prompt, `task: clustering | query: {content}`. It also offers
Matryoshka truncation to 512/256/128 dimensions; this project keeps 768.

History of this issue (kept so the record stacks vertically):
- 2025-11: under Ollama, `EmbeddingGemma:latest` returned "this model does not
  support embeddings" despite reporting a 768 embedding length.
- 2025-12: an Ollama update fixed it without any project change; the issue was
  closed.
- 2026: Ollama was replaced by llama.cpp (Issue 10-049); EmbeddingGemma 1 was
  brought back as a GGUF for the model comparison in Issue 10-031.
- 2026-10: the owner asked to look into the new version (note left in the
  project root as `new-issue-embedding-gemma-2`, folded into this issue and
  removed).

## Intended Behavior

EmbeddingGemma 2 is a fourth selectable model on the `local` server, loadable
by `start-llamacpp-server.sh --server=local --model=embeddinggemma-2`, producing
768-dimension vectors with the prompt phrasing its makers specify for
clustering, and evaluated alongside the other three in the Issue 10-031
comparison. Whether it replaces `nomic-embed-text-v1.5` as the default is
decided by that comparison, not assumed.

## Suggested Implementation Steps

1. **Update llama.cpp.** Raise the pinned tag in `scripts/build-deps.sh` to
   `b11454` or later and re-run the script. Confirm with the server's
   `--version` (needs the CUDA path the start script sets) that the build is
   new enough, and re-run one embedding with each of the three
   existing models to check the update did not shift their vectors (compare
   a few cached poem vectors against fresh ones by cosine similarity).
2. ~~Fetch the GGUF~~ — done (Q8_0 text model; the vision/audio projector
   file is not needed). `scripts/build-deps.sh` only downloads the nomic
   model; the other three GGUFs are fetched by hand.
3. ~~Read the model card for the task prompt~~ — done, unchanged from v1.
4. ~~Register the model~~ — done in `config.lua` and `src/similarity-engine.lua`.
5. ~~Smoke test~~ — done 2026-10-07 on a side port: ready in 3 s, 768
   numbers, identical text gives cosine 1.000000, unrelated texts 0.90
   (the shared offset that centring removes). Two fixes came out of it:
   - The build script's smoke test counted the server's 503 "still loading"
     reply as ready (the new llama.cpp opens its port before loading); it now
     waits for a 200, as the start script already did.
   - llama.cpp found the 1080 Ti cannot run Flash Attention and switched it
     off by itself. Servers in `config.lua` now take `launch_flags`, extra
     llama-server words for that machine's GPU; `local` states
     `--flash-attn off`, and the start script appends them last.
   Original step, with the procedure in Issue 1-011: server loads the file,
   returns 768 numbers, two different texts give different vectors, the same
   text twice gives the same vector.
6. **Long-text check.** The 8K context is four times the old one. Check how
   many poems now fit without the chunking from Issue 10-050, and whether
   the chunk size setting should follow the model.
7. **Run the Issue 10-031 comparison** with the new model added.
8. **Test the word-cloud ranking with it** (see Open questions).

## Open Questions

- The word-cloud "shape over meaning" problem was traced to the ranking, not
  the model, and fixed in Issue 8-050 (item 6). Does the fresh EmbeddingGemma
  2 build confirm it? `wordpage-shape-audit` style counts (how many pages the
  most frequent poem appears on) are the measure.
- Should `scripts/build-deps.sh` download every model in the `local`
  server's list, instead of only nomic? Three of four are fetched by hand.
  (Its smoke test is likewise nomic-only.)
- Six warnings remain when EmbeddingGemma 2 loads on b11476 with the start
  script's flags. Which are acceptable, and which need action?
  1. No API key, and any website may call the server (CORS open). The server
     listens on the LAN address; this applies to every model, not just this one.
  2-3. Two tokens in the GGUF (`</s>`, `<|tool_response>`) look like control
     tokens but are not marked as such; llama.cpp corrects their type. A flaw
     in the day-old conversion, possibly fixed by a re-upload.
  4. `</s>` is removed from the end-of-generation list. Affects text
     generation only.
  5. "embeddings required but some input tokens were not marked as outputs"
     -- llama.cpp switches every token to output for embedding mode.
  6. Speculative decoding is not supported in this context. A text-generation
     feature; unused here.
  Were 2-6 present with EmbeddingGemma 1 too? Not checked.
  6 is not a GPU limit: speculative decoding is a text-generation technique
  and is already off by default; stating `--spec-type none` was tested and
  does not silence it, so no flag was added.
  7. "failed to mlock ... Cannot allocate memory": the start script's
     RAM pin (`--load-mode mmap+mlock`, formerly `--mlock`; b11476 removed
     the old flag, which stopped the server from starting) needs more locked
     memory than this login allows (`ulimit -l` is 8 MB; the model needs
     ~171 MB). The pin has therefore never taken effect, for any model: a
     silent fallback. Raise the limit for this user, or drop the pin?
- If EmbeddingGemma 2 wins the comparison, do all per-model caches get
  regenerated at once, or does the old model's directory stay as the live
  site until the new one is complete?

## Related Documents

- Issue 1-011 — embedding model testing procedure (the smoke test)
- Issue 10-031 — embedding model evaluation framework (the comparison)
- Issue 10-049 — replacing Ollama with llama.cpp
- Issue 10-050 — batched embedding with long-text chunking
- `config.lua` — the `local` server's model list
- `scripts/start-llamacpp-server.sh` — loads the chosen model
- Sources: https://huggingface.co/ggml-org/embeddinggemma-2-GGUF ,
  https://www.marktechpost.com/2026/10/06/google-deepmind-releases-embeddinggemma-2-a-740m-open-multimodal-embedding-model-built-on-gemma-4/
