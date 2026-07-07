# 503 — Companion LLM Interface: abstract, swappable backend

> One narrow door between Phase 5 and whatever model speaks for the companions.
> A persona (and some context) goes in; a single utterance comes out. Nothing
> above this door knows which model answered — that is what lets a cloud model
> and a local model be two implementations of one contract.
>
> Foundational for the companion voice (504) and the summarizer (505). NCP = New
> Character Person; see [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md).

## Current Behavior

None of this exists yet. There is no way for any part of the game to ask a
language model for a line of speech or a summary, and no abstraction to keep the
rest of the code from hardcoding a vendor.

## Intended Behavior

A single abstract interface — call it the **companion LLM interface** — with one
essential shape:

- **In:** a persona/prompt (who is speaking and how), plus some recent context
  (what just happened; typically a memory slice from 502).
- **Out:** one utterance (a line of speech, or a summary — the same door serves
  both the voice in 504 and the summarize-and-save in 505).

The interface is **backend-agnostic**. Two backends are designed for from day one,
selected by config, never by the callers:

- **Canonical backend — Claude via the Anthropic API.** The persona becomes the
  system prompt; the recent context becomes the message history; the reply's text
  is the utterance. The **model tier is a config value**, not a constant: a fast,
  inexpensive tier for the frequent between-interaction chatter, and a stronger
  tier reserved for the heavier summarize-and-save compression (505). Per the
  project's statistics discipline, **exact model-ID strings live in a config
  file** (read at startup from `input/`), not baked into code or this doc — a
  model rename must not require a code edit.
- **Vision-imagined backend — a LOCAL model.** The vision dreams of a "powerful
  local AI" on the handheld. The same interface accepts a local adapter; only the
  adapter changes, never the callers. This is what lets the Anbernic target and
  the Anthropic API coexist.

Because a network/model call can fail, be slow, or be unavailable (no device, no
key, offline handheld), the interface must **fail loudly, not silently**: surface
the failure to the caller rather than returning an empty or fabricated line. Per
project policy, a fallback (e.g. a canned line when the model is unreachable) is a
*warning to be reported*, and if one is used it must be flagged and tracked in an
issue — never quietly substituted.

## Suggested Implementation Steps

1. Define the **request envelope** (persona + context) and the **response
   envelope** (one utterance + minimal metadata: which backend/tier answered, and
   token/latency figures if the backend reports them — useful later for the
   validator). Keep these plain data, backend-neutral.
2. Define the **backend adapter contract**: a single "produce an utterance from an
   envelope" operation plus a "which tiers are available" descriptor. Callers hold
   the contract, never a concrete backend.
3. Implement the **Anthropic/Claude adapter**: map persona → system prompt,
   context → messages, config-selected tier → model ID (read from config), reply
   text → utterance. Read model-ID strings and API credentials from config
   (`input/`), never hardcode. Support both a chatter tier and a summarizer tier.
4. Stub the **local-model adapter** to the same contract so the seam is proven to
   exist (even if it only echoes/loops for now) — this keeps the "swappable"
   promise honest and testable without a real local model present.
5. Implement **backend selection from config**: which adapter, which tiers. Default
   sensibly; report the choice at startup.
6. Make failure explicit: on backend error/timeout/absence, return a clearly-typed
   failure to the caller. If any fallback line is ever emitted, mark it, log it to
   `tmp/`, and note it as a warning to be resolved.
7. Write the file's `.info.md` documenting the one external operation (envelope in,
   utterance-or-failure out) so 504 and 505 read it rather than the source.

## Related Documents / Tools

- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) — "The LLM seam
  — abstract in, swappable behind."
- [input/startup](../input/startup) — where run-configuration (including backend
  and model choice) is read on launch.
- Used by: companion speech-pattern system (504), pattern summarize-and-save (505).
  Phase 6's Dungeon Master will want a *separate*, similarly-abstract interface for
  the strong generator — keep this one focused on companion speech so the
  weak/strong split stays clean.
