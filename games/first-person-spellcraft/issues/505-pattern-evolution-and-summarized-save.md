# 505 — Pattern Evolution & Summarized-Save

> Personas that *change and grow* between adventures, and a way to keep a grown
> persona as a new reusable pattern — but **summarized**, so behavior stays
> coherent and never bloats or drifts. This is "configure templates, never
> instantiations" applied to voices: you save the mold, not the transcript.
>
> Depends on 504 (the persona and uttering), 503 (summarizing is itself an LLM
> call), 502 (memory is the raw material of growth). NCP = New Character Person;
> see [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md).

## Current Behavior

None of this exists yet. A persona (504) is seeded from the common pattern and can
speak, but it never changes, and there is no way to capture an interesting grown
voice as a new starting pattern for future characters.

## Intended Behavior

Two linked capabilities, both drawn straight from the vision (*"speech patterns
that change and grow and guide between interactions. Each newborn character starts
from a common pattern, and the player can save patterns as new patterns (but
summarized, to ensure behavior remains coherent)"*):

- **Growth between interactions.** Between adventures, the active persona (504)
  folds in the residue of what happened — drawn from the memory store (502) — so
  the voice is not the same voice it was last run. Growth is bounded: the persona
  stays a *short brief*, so what "grows" is its character, not its length.
- **Summarized-save as a new pattern.** The player can **save a grown persona as a
  new reusable pattern**. Crucially the save is **summarized**: the grown voice is
  compressed back down into a short, coherent brief before it becomes a new
  template. The summarization is the safety mechanism — it is *what keeps behavior
  coherent* and *what prevents unbounded drift and prompt bloat*. A saved pattern
  is then a first-class template, usable exactly like the common pattern to seed
  future newborns.

The roadmap flags companion-speech **coherence** as Phase 5's chief risk. The
answer lives here, not in the backend: coherence is a property of keeping personas
short and re-summarized on save. Because summarizing is an LLM call, it runs
through the *stronger* tier of the LLM interface (503).

This is the "configure templates, never instantiations" strategem again — the
player edits and saves *molds* (patterns), and the world stamps *copies*
(instances). A saved pattern never reaches back into an already-living NCP.

## Suggested Implementation Steps

1. Write the **grow-persona operation**: take the active persona (504) plus a
   memory slice (502), produce an updated *short* brief. Enforce the shortness
   bound so growth cannot balloon the persona over many runs — express the bound
   as config, and if a growth step would exceed it, summarize rather than truncate.
2. Choose *when* growth happens (natural seam: end of a run / between interactions)
   and wire it there. Leave a comment explaining the choice and its alternative
   (grow-per-interaction vs. grow-per-run) so a future editor understands the
   trade-off.
3. Write the **summarize-and-save operation**: compress a grown persona into a
   short new pattern via the stronger LLM tier (503), then store it as a new
   template alongside the common pattern (504/501). Confirm the result is *shorter*
   and still coherent (a test that saves, reloads, and checks the brief is within
   the length bound and non-empty).
4. Make saved patterns selectable as seeds by the stamp operation (501), exactly
   like the common pattern — no special-casing.
5. Guarantee the mold/copy boundary: saving a pattern must not mutate any living
   instance's active persona. Add a test that saves from an instance and asserts
   that instance's own persona is unchanged.
6. If the summarizer LLM call fails, fail loudly (503's contract) — do not save a
   half-summarized or raw persona silently. Report it; a raw save would be a
   coherence hazard and counts as a warning to resolve.
7. Write the file's `.info.md` for the two operations, inputs/outputs as black boxes.

## Related Documents / Tools

- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) — "Companion
  persona" growth and summarize-and-save; "The LLM seam" (coherence via summary).
- [strategems](../strategems/README) — "configure templates, never instantiations."
- Builds on: speech-pattern system (504), LLM interface (503, stronger tier),
  memory store (502).
