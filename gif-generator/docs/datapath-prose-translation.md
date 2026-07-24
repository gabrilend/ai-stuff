# Datapath — from spoken prose to a scene script

This document follows a plain-English motion description onto the
porch, through three small minds, and in through the same front door
every scene uses. The pipeline behind that door never learns that a
model was involved.

## The premise

A person describing motion will sometimes say the wrong word, or
forget how to spell the right one, while describing the *mechanism*
perfectly. "It swooshes — slow, then quick, like flicking a brush."
That sentence contains the easing called `stroke`; it just doesn't
know the name. A small local language model is exactly enough machine
to hear the mechanism and write down the vocabulary word.

## The input: a prose file

A `.prose` file in `input/`: plain English, no format at all. The
founding vision file is the genre's first example.

## The porch, step by step

1. **The prompt is assembled from the truth.** The system prompt is
   built from the scene-format document and the shipped reference
   scenes (the vision translation is the flagship few-shot example).
   Nothing about the vocabulary is written twice — the prompt builder
   reads the same format document people read.

2. **The model paints in tool-calls, and the grammar makes
   misspelling impossible.** The model does not answer with a whole
   scene; it *paints*, one tool-call per stroke — a timeframe in
   seconds (tenths only), a color, a shape, a fade enum — in whatever
   order the prose brings them to mind. llama.cpp accepts a GBNF
   grammar that constrains every token it may emit; we *generate*
   that grammar from the vocabulary tables — the legal fade enums,
   easing names, hue names, shape kinds, the one-decimal time rule.
   The model is physically unable to output `strok` or invent
   `swoosh`; its entire freedom is *choosing among legal readings*.
   The collector orders arriving strokes by time (the canonical
   writer's walk-back insertion — decrement until no-op; equal times
   keep arrival order) and writes the canonical Lua score — a linear
   todo list, the person's own sentences carried as comments above
   the strokes they became.

3. **Three readings, not one refinement.** The prose goes to all
   three cluster nodes independently (or three seeds when only one
   node answers). Approaching the same problem from three perspectives
   yields three understandings — cheaper and stranger and better than
   polishing one guess three times. Each reading is compiled and
   rendered small and fast (low resolution, short duration — a
   thumbnail of the motion, not the final render).

4. **The wall does the arguing.** Each candidate scene faces the same
   validation wall as a hand-written one. Errors — which name their
   actor, their field, and their nearest legal word — are quoted back
   to the model verbatim for a bounded number of retries. A reading
   that still fails is shown to the person *with its errors*, never
   silently repaired, never silently dropped.

5. **The person picks.** A pick page (a viewing artifact, built like
   the gallery) shows the three moving thumbnails beside the original
   prose. Choosing one promotes its scene file into `input/` as a
   first-class citizen — indistinguishable, from that moment, from a
   scene someone typed.

## The cluster is configuration, not code — and it has an orchestrator

*"there will be an orchestrator"* (gabrilend, 2026-07-23). The porch
speaks to one door: the orchestrator's endpoint, named in
`input/cluster` (host, port, a name for affection). What stands
behind that door — three little minds, one split model, something
stranger — is the orchestrator's business, and the porch asks only
for readings. Multiple entries are still legal (the porch will fan
out to whatever doors it is given); zero entries means the porch
politely refuses with instructions, because a missing cluster is a
fact to report, not a condition to hide.

Transport is llama-server's HTTP completion interface via luasocket;
JSON via dkjson — both already on the shared library shelf
(`libs/lua/`). No new dependencies.

## What the porch may never do

- Reach past the wall (its output is validated like anyone's).
- Render the final gif (it renders thumbnails through the ordinary
  pipeline at small settings, nothing bespoke).
- Auto-pick a reading. Taste belongs to the person.

## Relevant pieces

- the prompt builder (format document + reference scenes, one truth)
- the grammar generator (vocabulary tables → GBNF, one truth)
- the cluster client (endpoints file, HTTP, three readings)
- the retry loop (wall errors quoted verbatim, bounded)
- the scene writer (JSON reading → Lua scene with prose comments)
- the pick page (thumbnails beside prose; promotion into input/)
