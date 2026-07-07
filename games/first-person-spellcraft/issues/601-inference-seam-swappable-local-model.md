# 601 — The inference seam: a swappable, local-first model interface

**Phase:** 6 (AI Dungeon Master & Learning)
**Depends on:** nothing in Phase 6 (this is the phase's taproot). Consumed by
every later Phase-6 issue.
**Blocks:** 604 (re-estimation may call the seam), 605b, 606, 607 (generation).

## Current Behavior

None of this exists yet. There is no way for the Dungeon Master to reach a
generative model, and no boundary separating "how we talk to a model" from "what
we ask it for." Without this seam, every later issue would hardcode a particular
backend and the loop could never be moved to a different model — including the
powerful **local** model the vision imagines (the "LLAMAI DM").

## Intended Behavior

A single, thin **seam** that is the only part of Phase 6 that knows a model
exists. Everything upstream hands it a **generation request** — a plain data
description of what is wanted — and gets back a **generation response** — a plain
data structure — with no knowledge of tokens, weights, or vendors.

Key properties:

- **Swappable backend.** The seam exposes one calling shape; behind it, a
  dispatch table of **backend adapters** (local-model adapter, and room for
  others) is selected by a config key read from `input/`. Adding a backend is a
  new table row, not a change to callers. Prefer a dispatch table over any
  if/else on backend name.
- **Local-first intent.** The default adapter targets a **local** inference
  process (llama-family weights on the same machine), because the vision wants
  the DM to run on the box, ultimately the handheld. This is intent, not
  lock-in — the seam must not assume locality in its interface.
- **The weak/strong split.** The seam takes a **model handle** argument
  identifying *which* model and *how much budget* to spend. The DM asks for the
  strong handle (generate a lair, once, think hard); the Phase-5 solver asks for
  the weak handle (solve a puzzle, often, cheap, allowed to fail). Same seam,
  different handle. Document *why* the asymmetry exists: if the solver matched
  the generator, every puzzle would solve instantly and the capability estimate
  (issue 602/604) would carry no information.
- **Structured in, structured out.** The seam validates that a response parses
  into the expected structure and **errors loudly** if it does not (no silent
  fallback to a canned lair — a fallback here would be a warning, and warnings
  are errors per project policy). If a stub/canned response is ever used for
  offline testing, it must announce itself.

## Suggested Implementation Steps

1. Define the **generation request** structure: a free-form context payload plus
   typed fields (target difficulty, chosen modality, primitive pool reference,
   learned-context summary). Keep it a plain table so callers build it without
   touching the seam.
2. Define the **generation response** structure and a **validator** that turns a
   raw model output into it or raises a clear error.
3. Define the **model handle**: which model + budget. Provide two named handles,
   strong (DM) and weak (solver), sourced from config.
4. Build the **backend-adapter dispatch table**, keyed by backend name from
   `input/`, with a **local-model adapter** as the default row.
5. Write the single **submit** function: takes a request + a handle, routes
   through the dispatch table, runs the validator, returns the response or errors.
6. Provide an **offline stub adapter** for tests that loudly announces it is a
   stub (so nobody mistakes canned output for real generation).
7. Companion `*.info.md` listing the submit function, the two handles, and the
   request/response shapes.
8. Tests: a request round-trips through the stub; a malformed response raises;
   the strong and weak handles route to their configured models; an unknown
   backend name errors instead of falling back.

## Meta

- **Fallback policy:** none. Missing/invalid model output errors; a stub must
  announce itself. Warnings are errors.
- **Sequel hook:** the same seam later serves Phase-8 province-trial generation.

## Related Documents / Tools

- [datapath-dungeon-master.md](../docs/datapath-dungeon-master.md) — "The
  inference seam" section and the weak/strong split.
- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) *(Phase 5)* —
  the weak solver that shares this seam.
