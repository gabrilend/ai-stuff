# Datapath — NCP Characters & LLM Companions (Phase 5)

> How data flows through Phase 5: from a lifeless **template**, to a living
> **New Character Person** who walks a lair on her own, guided by a companion
> voice that grows between adventures, attempting puzzles with a deliberately
> dull wit, and coming home changed by what she remembers.
>
> Part of the per-phase datapath set indexed in
> [table-of-contents.md](table-of-contents.md). Upstream of this phase:
> [Phase 1 engine](datapath-engine-foundation.md),
> [Phase 3 spells](datapath-spell-system.md),
> [Phase 4 puzzles & traps](datapath-puzzles-and-traps.md). Downstream of it:
> [Phase 6 Dungeon Master](datapath-dungeon-master.md),
> [Phase 7 economy](datapath-economy-settlement.md). It also touches
> [Phase 2 input](datapath-dual-mouse-input.md) at the takeover seam.
>
> Where this doc and the vision disagree, the [vision](../notes/vision) wins.

---

## Terminology — NCP (New Character Person)

The vision expands the acronym once, at line ~113: **"NCP - New Character
Person."** It also uses the ordinary word **NPC** loosely, interchangeably, for
the very same thing (e.g. "the NPC characters have to figure it out," "NPC
inventory lists"). This document — and every Phase 5 issue — **canonicalizes on
NCP (New Character Person)**. Read any "NPC" in the source poetry as the same
creature. Source code may keep the shorter `npc` token where a three-letter name
reads cleaner; the docs stay on NCP so the meaning never drifts.

---

## The spine of the flow

A single sentence, then the map:

> A **template** is stamped into an **instance** with its own per-stat levels,
> inventory, and memory; a **companion persona** (starting from the one common
> pattern every newborn shares) gives it a voice; the instance **explores a lair
> on its own**, and when it meets a Phase-4 puzzle it hands the puzzle to a
> **deliberately weak solver**; the solver's **success-or-failure** is both a
> signal Phase 6 reads and a new line written into **memory**; the run ends with
> the NCP carrying **treasure and requests** back to the Phase-7 economy — and at
> any moment the **player can take the wheel and aim**.

```
                        ┌───────────────────────────────────────────┐
                        │  NCP TEMPLATE   (a mold, never played)     │
                        │  · base per-stat levels                    │
                        │  · starting inventory manifest             │
                        │  · seed persona = the ONE common pattern   │
                        └───────────────────┬───────────────────────┘
                                            │  stamp / instantiate
                                            v
   ┌──────────────────────────────────────────────────────────────────────┐
   │  NCP INSTANCE  (a living adventurer for one run / one life)            │
   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────────┐ │
   │  │ per-stat     │  │ inventory    │  │ MEMORY STORE (append-only)   │ │
   │  │ levels       │  │ (carried +   │  │ · trial logs, puzzle outcomes│ │
   │  │ (each stat   │  │  found loot) │  │ · fairy-tales learned        │ │
   │  │  tuned       │  │              │  │   (written by Phase 6 library│ │
   │  │  separately) │  │              │  │    /learning mechanic)       │ │
   │  └──────┬───────┘  └──────┬───────┘  └───────────────┬──────────────┘ │
   └─────────┼─────────────────┼──────────────────────────┼────────────────┘
             │                 │                          │
             │                 │ (persona reads memory + stats for flavor & recall)
             v                 v                          v
   ┌───────────────────────────────────────────────────────────────────────┐
   │  COMPANION PERSONA  →  LLM INTERFACE (abstract: persona in, line out)   │
   │  · seeded from the common pattern; grows between interactions           │
   │  · summarize-and-save turns a grown persona into a NEW reusable pattern │
   │    (SUMMARIZED, so behavior stays coherent and cannot bloat/drift)      │
   │  backend is swappable ── Claude via the Anthropic API (canonical) ──┐   │
   │                       └─ or a LOCAL model (vision-imagined) ────────┘   │
   └───────────────────────────────────┬───────────────────────────────────┘
                                        │  guides / narrates / encourages
                                        v
   ┌───────────────────────────────────────────────────────────────────────┐
   │  AUTONOMOUS EXPLORATION  (drives the instance through a lair alone)      │
   │  move through Phase-1 rooms → engage the 4 combats → approach a puzzle   │
   └───────┬─────────────────────────────────────────────┬───────────────────┘
           │ (a puzzle is reached)                        │ (player intervenes)
           v                                              v
   ┌────────────────────────────┐            ┌────────────────────────────────┐
   │  WEAK PUZZLE SOLVER         │            │  PLAYER TAKEOVER + AIMING      │
   │  · deliberately weaker than │            │  · Phase-2 input abstraction   │
   │    the DM's strong generator│            │    drives the same NCP body    │
   │  · attempts the Phase-4     │            │  · Phase-3 aimed spells fire   │
   │    mechanism/solution       │            │    through the SAME aim path   │
   └───────┬────────────────────┘            └────────────────────────────────┘
           │ emits
           v
   ┌────────────────────────────────────────────────────────────────────────┐
   │  CAPABILITY SIGNAL  (success | failure, + which stat carried the attempt)│
   │   ├──► written into MEMORY STORE (this NCP now "knows" the outcome)      │
   │   └──► handed UP to Phase 6: "this party is that-potentialed"            │
   │        (weak-vs-strong asymmetry is what lets the DM estimate difficulty)│
   └────────────────────────────────────────────────────────────────────────┘
                                        │  run ends
                                        v
   ┌────────────────────────────────────────────────────────────────────────┐
   │  RETURN  →  Phase 7 economy: NCP arrives with gold/gems/notes/logs and   │
   │  makes REQUESTS the player fulfils from configured market templates      │
   └────────────────────────────────────────────────────────────────────────┘
```

---

## Structures, by role

Listed by what each one is *for*. Field lists are illustrative of intent, not a
frozen schema; the implementing issues own the exact shape. Names are given in
plain English first.

- **NCP template — the mold.** Holds base per-stat levels, a starting-inventory
  manifest, and a reference to a seed persona (the common pattern). Templates are
  *configured, never played* — the "configure templates, never instantiations"
  strategem (see [strategems](../strategems/README)). Stamping a template mints an
  instance; editing a template never touches already-living instances.
- **NCP instance — the living adventurer.** A stamped copy that owns: its own
  per-stat level block, a live inventory (starting manifest plus loot found this
  run), a handle to its memory store, a handle to its active companion persona,
  and a body/pose the engine can place in a room and the player can seize.
- **Per-stat level block.** One level *per stat*, tuned independently — not a
  single "character level." The DM (Phase 6) reads these exact per-stat numbers to
  fit a puzzle to the mind attempting it, so the stats must be addressable
  individually. (The vision's party-with-differing-per-stat-levels idea is noted
  but deferred: "save parties for the sequel" — single adventurer for now, stats
  still designed to support per-stat tuning.)
- **Inventory.** The carried goods: what the template handed over, plus gold,
  gems, resource notes, and trial logs picked up in the lair. This is the payload
  the Phase-7 economy reads on return, and the currency behind NCP requests.
- **Memory store — the append-only ledger.** Accumulating context: puzzle
  outcomes, trial logs, and the fairy-tales the Phase-6 library writes in to teach
  "mechanics of existence" (quaternion rotations, Newtonian bio-impedance, and
  other magical-histories). Append-only so history is honest; the more it holds,
  the more the weak solver and the persona can draw on. This is the seam Phase 6's
  learning mechanic writes into to make future puzzles easier.
- **Companion persona (speech pattern).** The prompt/character that drives the
  companion's voice. Every newborn is seeded from **the one common pattern**. A
  persona grows between interactions; a grown persona can be **summarized and
  saved as a new reusable pattern**. A saved pattern is a template too — the same
  strategem again, applied to voices instead of bodies.
- **Common pattern — the shared newborn seed.** The single baseline persona all
  fresh NCPs start from, so behavior has a coherent origin before it individuates.
- **Capability signal.** A small record emitted when a puzzle attempt resolves:
  success or failure, which stat carried the attempt, and enough context for the
  DM to update "how potentialed this adventurer is." Consumed by Phase 6; also
  copied into memory.
- **LLM request/response envelope (abstract).** Persona + recent context in, one
  utterance out. Deliberately backend-shaped-but-not-backend-bound (see the LLM
  seam below), so the companion voice and the summarizer are the same interface.

---

## Functions, by role

Described by the job they do, not their eventual code names. The implementing
issues assign real names and vimfold them.

- **Stamp a template into an instance** — copies base stats, expands the starting
  inventory manifest into a live inventory, attaches a fresh memory store, and
  clones the seed persona for this life.
- **Advance / read a per-stat level** — grow one stat independently; expose the
  per-stat block so the DM can read exact levels.
- **Append to memory / read memory context** — the only two doors on the memory
  store: one writes a new line (outcome, trial log, or a fairy-tale from Phase 6),
  one gathers relevant recent context for a persona utterance or a solver attempt.
  No editing, no deletion — append-only.
- **Utter (companion speaks)** — assemble persona + memory context into the
  abstract LLM envelope, get one line back, hand it to the player-facing view.
- **Grow the persona** — fold an interaction's residue back into the working
  persona so the voice changes between adventures.
- **Summarize-and-save a persona as a new pattern** — compress a grown persona
  into a shorter reusable pattern; the compression is what keeps behavior coherent
  and stops unbounded drift/bloat. (Itself an LLM call through the same interface.)
- **Attempt a puzzle with the weak solver** — take a Phase-4 puzzle handle plus
  the NCP's stats and memory, run the *deliberately weaker* reasoning, and produce
  an attempt (a chosen mechanism/trigger, or a give-up).
- **Emit the capability signal** — turn an attempt's outcome into the success/
  failure record, write it to memory, and publish it for Phase 6.
- **Drive autonomous exploration** — pick the next room, engage combats, walk up
  to puzzles, invoke the weak solver, and route treasure into inventory; step the
  whole loop each tick when no player is at the wheel.
- **Take over / release an NCP** — swap the exploration driver for the Phase-2
  input abstraction (and back), so the player's aim moves the same body the AI was
  moving a moment ago. Aim once, aim everywhere.

---

## Seams to other phases

Each seam is a narrow, named handoff — the strategems are "aim once, aim
everywhere" and "remember the demonstrated, re-estimate the meaning."

- **← Phase 1 (engine).** Autonomous exploration moves the NCP body through the
  square-room world and its collisions using the engine's existing movement and
  room graph; Phase 5 adds the *decisions*, not the *walking*.
- **← Phase 2 (dual-mouse input) & Phase 3 (spells).** The player-takeover seam
  routes the same input abstraction the wand uses into the NCP body, and Phase-3
  aimed spells fire through that same aim path — "anything that needs aiming, the
  user can aim, when they're playing as an NCP." Autonomous NCPs also *cast* those
  Phase-3 spells; the aim source differs (AI vs. player), the routing does not.
- **↔ Phase 4 (puzzles, mechanisms & traps).** Exploration hands each reached
  puzzle to the weak solver as an opaque handle; the solver picks a trigger; the
  puzzle system resolves it (solution, red-herring, or trap-on-failure). Phase 5
  owns the *dull attempt*; Phase 4 owns the *puzzle and its consequences*.
- **→ Phase 6 (Dungeon Master & learning).** Two wires cross here. Outbound: the
  **capability signal** tells the DM how potentialed the adventurer proved, so it
  can re-conceive what a "level" means. The **weak-vs-strong asymmetry** is load-
  bearing — the DM generates with a powerful model, the NCP solves with a weak one,
  and the gap is exactly what the DM measures difficulty against. Inbound: the
  Phase-6 **library / fairy-tale learning mechanic writes into this phase's memory
  store**, so a later run meets easier puzzles.
- **→ Phase 7 (economy & settlement).** On return, the NCP's inventory (gold,
  gems, resource notes, trial logs) is the economy's input, and the NCP's
  **requests** ("here, have a health potion; there's extra at the stockpile") are
  fulfilled from player-configured market *templates* — the same
  configure-the-mold strategem the persona system uses.

---

## The LLM seam — abstract in, swappable behind

The companion voice and the persona-summarizer both talk to the world through one
narrow interface: **a persona/prompt (and some recent context) goes in, a single
utterance comes out.** Nothing above this line knows or cares which model
answered. That keeps two backends in play without touching the callers:

- **Canonical backend — Claude via the Anthropic API.** The persona rides as the
  system prompt; the recent context rides as the message history; the reply's text
  is the utterance. Model *tier* is a config value, not a constant baked into code:
  a fast/inexpensive tier for the frequent between-interaction chatter, a stronger
  tier reserved for the summarize-and-save compression. Per the project's
  statistics discipline, the **exact model-ID strings live in a config file**, not
  hardcoded in the design — so a model rename can't rot this doc.
- **Vision-imagined backend — a LOCAL model.** The vision dreams of "a powerful
  local AI" on the handheld. The same interface accepts a local adapter; only the
  adapter changes. Designing to the interface (not the vendor) is what lets the
  Anbernic target and the Anthropic API coexist as two implementations of one
  contract.

Because the interface is this thin, the risk the roadmap flags for Phase 5 —
companion-speech *coherence* — is handled by the **summarized-save**, not by the
backend: coherence is a property of keeping personas short and summarized, so it
survives a backend swap.

---

## A note on counts

Per the project's statistics discipline, this doc hardcodes no counts — number of
stats, size of the common pattern, memory length caps, weak-solver "IQ" knobs, and
model tiers are all intended to be reported by a future validator / statistics
utility and configured in files, not restated here. The only fixed count is the
vision's own: a lair holds "three-ish puzzles and four combats exact," which the
exploration driver walks through.
