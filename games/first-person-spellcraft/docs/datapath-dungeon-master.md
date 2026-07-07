# Datapath — AI Dungeon Master & Learning (Phase 6)

> How data flows through the Dungeon Master: from an estimate of what a party can
> do, through the fresh generation of a lair, through the party's attempts, and
> back around to a sharper estimate and a better-tuned next lair. This is the
> feedback loop the vision calls out — "each time they conquer it, the AI
> remembers they are that potentialed and changes its conception of what a level
> means."
>
> Datapath docs describe **data flow and the roles of the pieces**, not their
> code. Names below are plain-English roles; the source files that realize them
> are listed at the end. When a count is needed (how many puzzle types exist, how
> many fairy-tales the library holds, how many stats a character has), this doc
> **refers to the Phase-6 statistics utility** rather than writing a number that
> will rot. The one number the vision fixes — "three-ish puzzles and four combats
> exact" per lair — is the only ratio stated here as law.

Related datapaths: [Phase 4 — Puzzles & Traps](datapath-puzzles-and-traps.md)
(the primitives the DM composes) and [Phase 5 — NCP Characters](datapath-ncp-characters.md)
(the per-stat levels, the success/failure signal, and the NCP memory the DM
reads and writes). The governing pattern is the strategem
**"Remember the demonstrated, re-estimate the meaning"** in
[strategems/README](../strategems/README).

---

## The loop, at a glance

```
   Phase 5: NCP per-stat levels ──┐
   Phase 5: NCP memory ───────────┤
   (accumulated fairy-tale learning)│
                                    v
                        (A) PARTY-CAPABILITY ESTIMATE
                            per-stat, with confidence
                                    │
                                    v
                        (B) DIFFICULTY TUNING
                    per-stat target + chosen challenge
                    modality (shadows / storm / pounding)
                                    │
              Phase 4 primitives    v
        (mechanisms, triggers, ─▶ (C) LAIR GENERATION
         traps, red-herrings)       composes ~3 puzzles + 4 combats,
                                    fresh every visit
                                    │
                                    v
                        (D) PARTY ATTEMPTS THE LAIR
                    Phase 5 solver (deliberately weaker)
                    works each puzzle; failure fires a trap
                                    │
                    success / failure signal (per puzzle, per stat)
                                    │
                                    v
                        (E) LEVEL RE-ESTIMATION
                "they are that potentialed" — update the
                capability estimate AND the DM's conception
                of what a "level" means (the yardstick)
                                    │
                                    └────▶ back to (A), sharper

   Side loop, feeding (A):
        LIBRARY VISIT ─▶ absorb a fairy-tale (quaternion rotation,
        Newton's laws, bio-impedance) ─▶ write into Phase 5 NCP memory
        ─▶ more context ─▶ the DM accounts for it ─▶ puzzles get easier
```

Read the loop as five stages A–E plus one side loop. A and E are the "remember
and re-estimate" pair; B and C are the "make a lair that suits them" pair; D is
where Phase 5 actually plays; the side loop is the library.

---

## The inference seam (abstract, swappable, local-first)

The DM's heavy lifting — inventing a lair that suits a party — is done by a
**powerful generative model**. The vision imagines this running **locally** (it
jokes about a "LLAMAI DM"), so the design intent is local inference on the same
box that runs the game. But the datapath treats the model as a **seam**, not a
vendor: everything upstream hands the seam a **generation request** (a
structured description of the party, the difficulty target, the chosen modality,
the pool of Phase-4 primitives available, and what the party has already
learned) and everything downstream consumes a **generation response** (a
structured lair spec). Swap llama-family local weights for anything else and the
loop does not change, because only the seam knows what a model is.

The **weak/strong split** is a load-bearing asymmetry, not an accident:

- The **DM** (this phase) uses the *strong* model to **generate** — it may take
  seconds, run once per lair, and think hard.
- The **NCP solver** ([Phase 5](datapath-ncp-characters.md)) uses a
  *deliberately weaker* model to **solve** — it runs many times, must be cheap,
  and is *supposed* to sometimes fail, because failure is the signal stage (E)
  learns from. If the solver were as strong as the generator, every puzzle would
  be solved instantly, the capability estimate would peg to maximum, and the
  loop would carry no information. The gap between "who built it" and "who solves
  it" is what makes the difficulty estimate meaningful.

Both sides reach their model through the same seam interface; they differ only
in **which model handle** they were given and how much budget they spend. See
issue 601.

---

## Data structures, by role

- **Party-capability estimate** — the DM's current belief about a party, keyed
  **per stat** (the stat set is Phase 5's; ask the statistics utility for the
  count and names). For each stat: an estimated level, a confidence/uncertainty,
  and the demonstrated ceiling so far. Designed per-stat now even though parties
  are a sequel feature, so a single NCP is just a party of one.

- **Level yardstick (the "conception of a level")** — the mapping from *raw
  demonstrated performance* to a *level number*. This is the thing the vision
  says the DM "changes" — not the party, the **ruler it measures with**. When a
  party conquers what the yardstick called "level N," the yardstick itself
  stretches so that N now demands more. Kept separate from the capability
  estimate so the two can be reasoned about independently.

- **Accumulated learning ledger** — per character (lives in Phase 5 NCP memory,
  read by the DM): which fairy-tales have been absorbed, and therefore which
  real mechanics the character now "knows" (three-dimensional rotation /
  quaternions, Newton's laws, bio-impedance, and other magical-histories). More
  entries here means the DM expects the relevant puzzles to come easier.

- **Fairy-tale** — one library artifact: a story that teaches exactly one
  mechanic, tagged with the puzzle families that mechanic unlocks and the stats
  it bolsters. The corpus is a data table (count via the statistics utility),
  not code, so tales can be added without touching the loop.

- **Challenge-modality descriptor** — one of **shadows** (stealth / darkness),
  **storm** (environmental / chaos), **pounding** (brute force). Each carries the
  generation strategy the DM uses when it "attempts to overcome them through"
  that modality. Held in a **dispatch table** keyed by modality name — never an
  if/else chain — so a fourth modality is a new table row.

- **Difficulty target** — the per-stat output of tuning: for each stat, how hard
  this lair should lean on it, plus the chosen modality and any easing from the
  learning ledger. This is the bridge between "what we believe about them" and
  "what we build."

- **Lair spec** — the structured generation response: a small room layout
  holding **~3 puzzle specs** and **exactly 4 combat specs** (the one fixed
  ratio), each tagged with the modality and the stat(s) it leans on. Fresh every
  visit — never cached, never reused.

- **Puzzle spec** — one puzzle inside a lair, expressed purely as references
  into Phase-4 primitives: a mechanism (the thing that provides the solution),
  its multiple triggers (including equal-seeming red-herrings), the solution
  path, and the **trap that fires on failure** (and whether disarming that trap
  is itself the puzzle).

- **Combat spec** — one of the four combats: which foes, arranged how, leaning on
  which stats.

- **Generation request / generation response** — the two sides of the inference
  seam (see above).

- **Attempt outcome** — the success/failure signal returned from Phase 5 for a
  single puzzle: solved-or-not, which stats were exercised, how close a failure
  came, and whether a trap fired. The raw food of stage E.

---

## Functions, by role

- **estimate the party's capability** — read Phase-5 per-stat levels + the
  learning ledger, produce the capability estimate (stage A).
- **choose a challenge modality** — dispatch-table pick of shadows / storm /
  pounding for this lair, biased by where the party is weak (part of stage B).
- **compute the per-stat difficulty target** — fold capability estimate + level
  yardstick + learning-ledger easing into a difficulty target (stage B).
- **compose a lair** — the generator: assemble the difficulty target, modality,
  and the Phase-4 primitive pool into a generation request, call the inference
  seam, and validate the response into a lair spec of ~3 puzzles + exactly 4
  combats (stage C).
- **instantiate fresh puzzles** — turn each puzzle spec into live Phase-4
  mechanisms/triggers/traps for this visit only (stage C).
- **wire the trap-on-failure** — connect each puzzle's failure to its trap, per
  Phase 4 (stage C / D boundary).
- **re-estimate the level** — consume attempt outcomes; update both the
  capability estimate and the level yardstick (stage E). This is the strategem
  in code.
- **record a library visit** — absorb a fairy-tale into the accumulated learning
  ledger, writing through into Phase-5 NCP memory (side loop).
- **account for learned context** — when tuning, discount difficulty on puzzle
  families whose enabling fairy-tale has been absorbed (side loop → B).
- **the DM tick / orchestration** — runs A→B→C, waits for D's outcomes, runs E,
  loops. The capstone that owns the lifecycle.
- **the inference-seam call** — submit a generation request, receive a
  generation response; the only function that knows a model exists.
- **the Phase-6 statistics utility** — reports live counts (puzzle types,
  fairy-tale corpus size, modality count, stat count) so no doc hardcodes them.

---

## Source files, by role (+ why)

Indexed filenames per project convention; the numeric prefix is assigned from
`.file-index-counter` at creation time, so the stems (not fixed numbers) are
listed here.

- **inference-seam** — the abstract, swappable model interface (local-first).
  *Why:* one place knows what a model is, so the backend can be replaced without
  disturbing the loop.
- **party-capability-model** — the capability estimate + the level yardstick and
  the code that reads Phase-5 stats. *Why:* the DM's belief about a party is the
  hub every other stage reads or writes.
- **level-re-estimation** — stage E. *Why:* isolates the "remember and
  re-estimate" strategem so its feedback math is testable alone.
- **challenge-modality-dispatch** — the shadows/storm/pounding dispatch table.
  *Why:* keeps modality selection a data lookup, and makes a fourth modality a
  one-row change.
- **library-and-fairy-tales** — the fairy-tale corpus + the library-visit
  accumulation that writes Phase-5 memory. *Why:* the learning side loop is its
  own concern, separable from generation.
- **difficulty-tuning** — stage B. *Why:* the single place that turns belief +
  learning into a per-stat target, so tuning policy lives in one file.
- **lair-generator** — stage C. *Why:* composing Phase-4 primitives into the
  fixed ~3-puzzle / 4-combat lair is the phase's centerpiece capability.
- **dungeon-master** — the tick / orchestration that runs the whole loop. *Why:*
  someone must own the lifecycle and the ordering of A→E.
- **statistics-dungeon-master** — the counts validator. *Why:* docs and demos
  reference it instead of hardcoding figures that rot.
- **phase demo** (in `issues/completed/demos/`) — a runnable showing the loop
  tightening over several visits. *Why:* the demo is part of the deliverable.

Each source file gets a companion `*.info.md` listing its externally usable
functions and their inputs/outputs, per project convention.

---

## What flows in, what flows out

- **In, from Phase 5:** per-stat NCP levels; the success/failure signal per
  puzzle attempt; a read/write handle to NCP memory (for the learning ledger).
- **In, from Phase 4:** the pool of puzzle/mechanism/trap primitives to compose.
- **In, from the seam:** a generation response (a candidate lair spec).
- **Out, to Phase 5:** learning-ledger writes (library visits) into NCP memory.
- **Out, to the world:** an instantiated lair (Phase-4 live mechanisms) for the
  party to attempt.
- **Out, to Phase 8 (later):** the same generator produces province trials, and
  the same re-estimation prices how a province "relationship" hardens — noted as
  a forward hook, not built here.
