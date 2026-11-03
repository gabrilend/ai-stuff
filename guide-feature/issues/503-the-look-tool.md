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
