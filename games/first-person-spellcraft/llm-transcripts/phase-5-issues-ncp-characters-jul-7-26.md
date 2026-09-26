# Conversation Summary: agent-a7a29dc1c082dc148

Generated on: 2026-09-26 12:47:07
Models: claude-opus-4-8

--------------------------------------------------------------------------------

### User Request 1

You author the DESIGN DOCS and ISSUE FILES for PHASE 5 (NCP Characters & LLM
Companions) of a game project. Write access is enabled — use the `Write` tool
for ALL files. Use the `Read` tool to inspect (NOT bash `ls`; read-only
`grep`/`find` fine). No bash file/dir targeting. No git commits. Do NOT edit
shared files (docs/table-of-contents.md, .file-index-counter) — only CREATE
your datapath doc + your phase's issue files.

PROJECT ROOT: /mnt/mtwo/programming/ai-stuff/games/first-person-spellcraft

FIRST, Read in full: notes/vision, docs/vision-overview.md, docs/roadmap.md,
docs/table-of-contents.md.

TERMINOLOGY: the vision uses "NCP" and "NPC" interchangeably but explicitly
expands "NCP - New Character Person" (vision ~113). CANONICALIZE on **NCP (New
Character Person)** throughout your docs/issues; note once that the source uses
NPC loosely for the same thing.

=== COMMON CONVENTIONS ===
- Language: Lua / LuaJIT-compatible. Disprefer Python. Disallow Lua-5.4-only
  syntax.
- GREENFIELD: "Current Behavior" starts from "none of this exists yet."
- Issues are BLUEPRINTS for building piece-by-piece, NOT work logs; readable in
  dependency order.
- Prefer LISTING structures / functions (by role) / files (+ why) over code
  snippets; plain-English over code names.
- Every issue needs AT LEAST: `## Current Behavior`, `## Intended Behavior`, `##
  Suggested Implementation Steps`. Optional stats/meta + `## Related Documents /
  Tools`.
- When integrating an LLM: this project's canonical models are Claude (e.g.
  Opus/Sonnet/Haiku) via the Anthropic API for companion speech, but note the
  vision also imagines a LOCAL model. Describe the LLM interface abstractly (a
  prompt/persona in, an utterance out) so the backend is swappable; don't
  hardcode a vendor in the design.

=== ISSUE FILE NAMING ===
issues/`{PHASE}{ID}-{desc}.md`. PHASE 5: issues/501-...md, 502, ... Foundational
lower, capstone higher. Large → sub-issues 5NNa/5NNb.

=== YOUR DATAPATH DOC ===
Create docs/datapath-ncp-characters.md — DATA FLOW: an NCP template →
instance with per-stat levels + inventory + memory → companion speech pattern
(persona) → autonomous exploration → weak solver attempts Phase-4 puzzles
→ success/failure signal out (to Phase 6) → accumulated memory. Show the
seams to Phase 2/3 (player takeover + aiming), Phase 4 (puzzle attempts), Phase
6 (capability signal + learning), Phase 7 (returns with treasure, makes
requests). List structures/functions by role. The TOC already forward-declares
this path — do NOT edit it.

=== PHASE 5 — NCP CHARACTERS & LLM COMPANIONS ===
Capability slice: autonomous adventurers with growing LLM companion personas.
Depends on: Phase 1, Phase 3 (spells they cast), Phase 4 (puzzles they attempt).
Relevant vision lines ~54-67 ("to prevent character burn-out, they will have LLM
companion speech patterns that change and grow and guide between interactions.
Each newborn character starts from a common pattern, and the player can save
patterns as new patterns (but summarized, to ensure behavior remains coherent)";
the AI monsters make lairs; "the NPC characters have to figure it out with a
weaker version"; "each time they conquer it, the AI remembers they are that
potentialed") and ~112-114 (player can aim when playing as an NCP).

Design surface (suggested; adjust freely):
- NCP data model: PER-STAT levels (the DM in Phase 6 tunes puzzles to exact
  per-stat levels), inventory, and a memory store. (Vision ~81-84 notes parties
  have differing per-stat levels — but "save parties for the sequel", so
  single-adventurer now; still design stats to support per-stat tuning.)
- Companion speech-pattern system: a persona/prompt that drives the companion's
  speech; the "common pattern" every newborn character starts from.
- Pattern EVOLUTION & summarized-save: patterns change/grow/guide between
  interactions; the player can SAVE an evolved pattern as a NEW reusable
  pattern, but SUMMARIZED — summarization keeps behavior coherent and prevents
  unbounded drift/bloat. This is the "configure-templates-never-instantiations"
  idea applied to personas.
- Autonomous exploration behavior: NCPs navigate lairs on their own (move
  through Phase-1 rooms, engage combats, approach puzzles).
- The WEAKER puzzle-solving AI: NCPs attempt Phase-4 puzzles with a DELIBERATELY
  weaker solver than the DM's powerful generator (the weak/strong asymmetry
  matters for the DM's difficulty estimation). Emit a success/failure signal
  Phase 6 consumes.
- Player takeover & NCP aiming: the player can take control of an NCP and aim
  — integrates Phase 2's input abstraction + Phase 3 aimed spells.
- NCP memory store: accumulates context (this is what the Phase-6
  library/fairy-tale learning mechanic writes into to make future puzzles
  easier).

Aim for ~6–8 issues, sub-issues for large ones.

When done, return: the datapath doc path + a numbered list of issue files (id +
title + one-liner).

--------------------------------------------------------------------------------

### Assistant Response 1

> I'll start by reading the required context files in full.

> Let me inspect the existing project structure to match conventions before
> authoring.

> No existing issue files or datapath docs yet — greenfield, as expected. Let
> me quickly check the narrative directories for any input context.

> This is greenfield with clear conventions and a strong narrative voice. Since
> issue 503 will describe a Claude/Anthropic-backed companion LLM interface, let
> me ground that against current API facts before writing.

> Permission for the claude-api skill was denied — that's fine, since the
> design must keep the LLM backend abstract and swappable anyway. I'll describe
> the Anthropic/Claude backend at the level of its stable shape (a persona as
> system prompt, a messages list, a configurable model tier, text out) and defer
> volatile specifics like exact model-ID strings to a config file, consistent
> with the project's "don't hardcode facts, reference a config/validator"
> discipline.
>
> Now I have everything I need. Let me write the datapath doc.

> Now the issue files. Starting with the foundational data model.

> Now the weak puzzle solver, split into two sub-issues since it's large.

> Now the capstone: player takeover and NCP aiming.

> All files written. Let me verify the complete set.

Phase 5 authored. All files are in place; I did not touch the shared TOC or
`.file-index-counter`, and made no git commits.

## Datapath doc
`/mnt/mtwo/programming/ai-stuff/games/first-person-spellcraft/docs/datapath-ncp-characters.md`

Traces the full flow: template → stamped instance (per-stat levels + inventory
+ memory) → companion persona seeded from the common pattern → autonomous
exploration → weak solver attempts Phase-4 puzzles → capability signal (out
to Phase 6, and into memory) → return with treasure/requests (Phase 7). Lists
structures and functions by role, and names every seam (Phase 1 movement, Phase
2/3 aim-once-aim-everywhere takeover, Phase 4 puzzles, Phase 6 capability signal
+ library-writes-into-memory, Phase 7 economy). Includes the abstract, swappable
LLM seam (Claude via Anthropic API canonical, local model imagined) with model
IDs deferred to config per the statistics discipline.

## Issue files (8 issues; 506 split into two sub-issues), dependency-ordered
1. **501 — NCP Data Model: template, instance, and per-stat levels** — the
   taproot: mold vs. living copy, per-stat level block addressable for DM
   tuning, single-adventurer now (parties deferred).
2. **502 — NCP Memory Store: append-only accumulating context** — the honest
   ledger; two doors (append / gather); the seam Phase 6's fairy-tale learning
   writes into.
3. **503 — Companion LLM Interface: abstract, swappable backend** — persona
   in / utterance out; Anthropic-Claude adapter (tier from config) plus a
   local-model adapter to the same contract; fails loudly, no silent fallback.
4. **504 — Companion Speech-Pattern System & the Common Pattern** — the one
   shared newborn seed and the act of uttering; voice reads, never acts.
5. **505 — Pattern Evolution & Summarized-Save** — personas grow between
   runs; save-as-new is summarized to keep behavior coherent (the roadmap's
   flagged risk answered here, not in the backend).
6. **506a — Weak Puzzle Solver: the deliberately dull wit** — bounded
   competence gated by per-stat level and lifted by learned memory; genuinely
   fallible.
7. **506b — Capability Signal & the Weak/Strong Asymmetry** —
   success/failure record written to memory and published up to Phase 6;
   deliberately hides the solver's knobs so the DM's difficulty estimation stays
   honest.
8. **507 — Autonomous Exploration Behavior** — the "plays itself" decision
   loop over the fixed lair shape (3-ish puzzles, 4 combats), adding decisions
   atop Phase-1 walking.
9. **508 — Player Takeover & NCP Aiming** — capstone: a thin routing swap so
   the two-mouse boomstick and Phase-3 aimed spells drive the same body;
   includes the Phase-5 demo brief as a deliverable.

Key conventions honored: canonicalized on NCP (New Character Person) with the
NPC-is-loose note stated once; greenfield "Current Behavior" throughout;
structures/functions listed by role in plain English rather than code; each
issue carries the three required sections plus Related Documents/Tools; no
hardcoded counts (deferred to config/validators); source file names left
index-free with a note that numeric prefixes are assigned from
`.file-index-counter` at implementation time.

--------------------------------------------------------------------------------

