# 503 — A model, or a relay, on each fg-sora

phase 5, bringing up the fg-sora machines

## Current behavior

No language model runs on the fg-sora machines.

## Intended behavior

Each fg-sora is set up for the backend its voice uses (401, 402):

- `local-llama`: a llama.cpp server built for the i5-8500T (AVX2 and FMA,
  **not** AVX-512, so a build tuned for kuvalu's processor would crash there
  with an illegal instruction) and the machine's C library, with a model
  that fits 8 GB alongside rmail and the thinker;
- `remote-llama` or `remote-api`: nothing to install but the thinker, plus
  the secrets file for the remote service, copied outside the repository.

## Suggested implementation steps

1. Build llama.cpp on kuvalu for the target (minimal-llm's
   `docs/006-build-and-toolchain.md` may already cover this).
2. Copy, start on boot, and check with a token-count request.
3. Record each machine's model and backend in `docs/architecture.md`.

## Related documents

- `docs/datapath-thinker.md`, "Inference backends"
- `/home/ritz/programs/risc-v-ollama/issues/301a-sora-strand-deployment.md`
  (model size suggestions for this hardware)

## Open questions

- Which model on each machine (`docs/open-questions.md`, 12).

## Blocked by

402, 501.

## Blocks

504.
