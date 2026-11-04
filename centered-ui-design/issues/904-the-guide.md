# 904 — The guide

**Phase:** 9 — Reading the machine
**Blocked by:** 901, 902, 903
**Blocks:** 905
**Related documents:** delta-version issue 065

## Current Behavior

No guide. The map (901, 902) and the room (903) have no reader-facing side.

## Intended Behavior

Whichever local AI is installed and free to work walks a reader through the
map. It follows the index order by default and steps back to a more
foundational stop when the reader seems not to be getting a part, then
returns. It judges this only from what the reader does on their own —
questions, "show me more", skips — and never asks questions to grade answers:
this is reading, not a test. It weighs that evidence as bets about the
reader's underlying aim.

The reader can always say "yeah yeah I get it"; the guide must then give the
summary of that stop, file or chapter. Skipping to nothing is not allowed.

A guide need not be an AI. With no AI present the reader picks from a list
of options at each stop, in index order, and that is a full reading — the
form for small devices like a watch, drawn for OLED screens only (black
background, lit pixels only for text).

Reader actions: **next**, **more** (other uses), **why** (recorded
alternatives), **skip** (summary), and free questions.

## Suggested Implementation Steps

1. The walk without an AI first: steps the map in index order with next /
   more / why / skip / back. A full reading on its own, and the base the AI
   guide builds on. A second build targets small OLED screens.
2. Local model client (llama.cpp or ollama from the shared libs folder).
3. Guide loop: current stop, last few reader actions, next few stops → the
   model's choice of next, step back, more, or summary.
4. Trail entries written through 903.
