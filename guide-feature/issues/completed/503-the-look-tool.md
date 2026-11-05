# 503 — The look tool: focused or broad

phase 5, looking into the project

## Current behavior

A look call during a turn is answered with "not built yet" (404).

## Intended behavior

The owner: "the tool call will be able to say 'I want a highly focused
insight' or 'I want a broad reaching exploration.' and it'll deliver more or
less similar or related pieces of architecture."

`look(about, focus)`, as designed in
`docs/datapath-looking-into-the-project.md`:

- **in**: `about` (text) and `focus` (decimal, 0 broad to 1 focused);
- embeds `about` with the `embedder` endpoint, using the index's own
  name-extraction rule;
- reads the clone's index (`.embedding-index/`), refusing one whose commit
  is not the clone's;
- scores every piece by cosine (a dot product, since vectors are normalised);
- picks pieces by focus: the nearest few at 1, a spread across the whole
  range of similarity at 0, a blend between. The curve is a setting;
- **out**: the chosen pieces' source text, nearest first, each labelled with
  file, lines and similarity, up to the token budget left in the turn.

No index means an error the model sees, and a count. It never falls back to
random files.

Scoring thousands of vectors is done in one pass over the vector file loaded
into one block of memory with LuaJIT's FFI, so it costs milliseconds.

## Suggested implementation steps

1. Load the index; score; pick by focus; fill to budget.
2. Plug into the ask loop (404) in place of "not built yet".
3. Tests against guide-feature's own index (502): the same `about` at focus
   1, 0.5 and 0 returns visibly different sets, recorded as reference files.

## Related documents

- `docs/datapath-looking-into-the-project.md`
- `docs/embedding-index-contract.md`

## Open questions

- The call's form (`docs/open-questions.md`, 3).

## Blocked by

405, 501, 502.

## Blocks

504.

## Decisions (2026-11-05; each the owner's to overturn)

1. **The call's form stays the plain line of 403**, `look focused: WORDS`
   or `look broad: WORDS` (open question 3, answered for now). The
   issue's `focus` decimal is kept underneath: `input/look` turns the two
   words into focuses (`focused = 1`, `broad = 0`), and the tool itself
   takes any focus from 0 to 1, so the model's words can stay two while
   the numbers change, or a third word be added later, without touching
   the code. The demo (504) asks at five focuses directly.
2. **Choosing by rank, not by similarity value.** The pieces are ranked
   nearest first; `nearest` (4) at focus 1 and `spread` (12) at focus 0,
   a straight line between; evenly spaced from rank 1 down to `(1 -
   focus) ^ curve` of the way to the last rank, `curve` = 2. Ranks behave
   the same for any embedding model, where similarity values do not (the
   stand-in's are mostly 0; a real model's crowd between 0.3 and 0.8).
3. **The budget is a setting**, `budget` = 2000 tokens a look, counted with
   the voice's own chat endpoint's tokenizer, not "the context length
   minus what the turn uses": the canvas's endpoint line names no context
   length, and with `look-limit` 3 a turn's looks add at most 6,000
   tokens. A piece that does not fit is left out and counted, and a smaller
   one after it still goes in, so one long piece cannot empty the answer.
4. **The voices copy kuvalu's index rather than build their own.** The
   clone keeper (058, `bring_index`) reads the meta of the index in the
   source's project folder and copies the index whole (`tar` over the
   same SSH as the clone) when it is at the clone's commit, or at another
   commit with the same project tree (copied with its commit renamed, as
   the builder renames its own). Vectors are then made once, by one model,
   on kuvalu's GPU; a voice needs no embedding work, and guide-feature
   keeps building only its own index, as 502's guide says. The 502 note
   that the turn would build the clone's index is corrected.
5. **An index behind the clone is not used.** The keeper leaves the old
   copy and says "behind"; a look then says the index is from another
   commit. A stale index would show lines that are no longer there.
6. **The embedder comes in the canvas.** kuvalu writes one more endpoint
   line, `endpoint: embedder NAME TIMEOUT ADDRESS`, last, when its
   `endpoints` has `use.embedder`; a voice reads it with `from_canvas(...,
   "embedder")` as an embedding endpoint. Like the voices' own endpoints,
   it is switched on kuvalu with `scripts/use-endpoint embedder NAME`.
7. **Every refusal reaches the model as a sentence and is counted**
   (`look-refused-<kind>`): no clone, no index, an index from another
   commit, another name rule or another model (its `/v1/models` name
   against the index's `model`, and the vector's length), no embedder, no
   names in the words. Nothing falls back to other files. A look that
   cannot be asked at all is "The look failed: ..." and `look-failed`. The
   turn goes on in every case.
8. **Reference looks are pinned to a commit**: the test builds
   guide-feature's index from its files at be7b82761 (issue 502's commit),
   so `assets/test-looks/` stays right as the project changes. A checkout
   without that commit skips them and says so.

## What was built (2026-11-05)

- `src/064-look.lua` (the look tool, runnable by hand) and `input/look`.
- `src/058-project-clone.lua`: `bring_index`, `describe_index`, `on_host`;
  `keep` returns `full` and `index`.
- `src/055-turn.lua`: `looker`, the index's log line and counts.
- `src/035-to-voices.lua` and `src/046-model-caller.lua`: the embedder's
  line in the canvas.
- `src/043-rehearsal.lua` copies `input/look` into its workspace.
- `src/065-test-look.lua` and `assets/test-looks/`: 56 checks.
- Docs: `datapath-looking-into-the-project.md` ("As built"),
  `datapath-voice-turn.md`, `canvas-format.md`, `endpoints.md`, the
  contract and the build guide.

## Needs the owner's machine

- `budget`, `nearest`, `spread` and `curve` tried with the real chat and
  embedding models, and the reference looks read by eye against the real
  index (the stand-in's similarities only count shared names).
- The index copied over SSH from kuvalu to each voice, once 501's SSH by
  key and 502's hooks on kuvalu are in place.
