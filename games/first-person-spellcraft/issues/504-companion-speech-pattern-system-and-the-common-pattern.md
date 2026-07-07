# 504 — Companion Speech-Pattern System & the Common Pattern

> The voice that keeps an adventurer from burning out. Every newborn starts from
> the one common pattern; the pattern drives a companion who narrates, guides, and
> encourages between interactions. This issue builds the persona and the act of
> speaking; how a persona *grows and is saved* is issue 505.
>
> Depends on 501 (an instance to attach a persona to), 502 (memory feeds speech
> context), 503 (the LLM door the voice speaks through). NCP = New Character
> Person; see [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md).

## Current Behavior

None of this exists yet. NCP instances (501) have a persona *handle* but nothing
fills it; there is no common pattern, and no way for a companion to say anything.

## Intended Behavior

A **companion persona** (a "speech pattern") is the prompt/character that drives a
companion's voice. The vision's purpose is explicit: *"to prevent character
burn-out, they will have LLM companion speech patterns that change and grow and
guide between interactions."* This issue delivers the persona itself and the act
of uttering; the growth/save loop is 505.

- **The common pattern.** There is exactly **one** baseline persona that every
  newborn NCP starts from — *"Each newborn character starts from a common
  pattern."* It is the shared origin that makes behavior coherent before a
  character individuates. It is authored once, stored as data, and cloned onto each
  instance at stamp time (501).
- **Uttering.** When the companion should speak (between interactions — entering a
  room, before a puzzle, after a combat, on return), the system assembles the
  active persona plus a **memory context slice** (502) into the abstract LLM
  envelope (503) and gets back one line, which is handed to the player-facing view.
- **Guidance, not autopilot.** The companion *guides* — it narrates and encourages
  and hints — it does not itself decide the NCP's moves (that is exploration, 507)
  nor solve puzzles (that is the weak solver, 506). Keep the voice a *read* of the
  NCP's situation, cleanly separated from the systems that *act*.

The persona is small and legible — a short character brief, not a transcript.
Keeping it small is what will let 505 grow and re-summarize it without drift.

## Suggested Implementation Steps

1. Author **the common pattern** as data: a short, coherent baseline persona brief
   (voice, disposition, how it guides). Store it where the stamp operation (501)
   can clone it. Do not hardcode its length in docs; a validator can report it.
2. Define the **active persona** structure carried on an instance: the working
   character brief the companion currently speaks from (seeded as a clone of the
   common pattern).
3. Write the **utter operation**: gather a memory slice (502), combine with the
   active persona, send through the LLM interface (503), return one line. Decide
   *when* to speak by situation (room entry, pre-puzzle, post-combat, return) —
   express those trigger points as a small dispatch table keyed by situation
   rather than a chain of if/else, so new speaking moments are cheap to add.
4. Route utterances to a player-facing view seam (a simple text sink for now; the
   real HUD is Phase 1/2's concern). Keep the *speech generation* isolated from the
   *speech display* — data generation and data viewing stay separate.
5. Add a comment at every persona-vs-action boundary explaining the split (why the
   voice reads but does not act), so a future editor does not accidentally let the
   companion start driving the body.
6. Write the file's `.info.md`: the utter operation and the common-pattern accessor,
   inputs/outputs, as black boxes.

## Related Documents / Tools

- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) — "Companion
  persona" and "Common pattern" structures.
- Builds on: LLM interface (503), memory store (502), data model (501). Grown and
  saved by: pattern evolution & summarized-save (505).
