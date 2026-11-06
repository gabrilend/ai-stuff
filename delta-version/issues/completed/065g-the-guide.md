# Issue 065g: The Guide

**Status**: Completed 2026-10-10
**Parent**: 065-the-reading-walk.md
**Dependencies**: 065d, 065e, 065f
**Blocks**: None

## Current Behavior
`scripts/reading-walk.lua <project> --guide=<room>` walks with a guide; the
judgement is `scripts/libs/reading-guide.lua`. Tests (with stand-in AIs) are
in `scripts/test-reading-walk.sh`. Tried once with a real local model
(llama3.2 through ollama on the GTX 1080 Ti): its answers were read as moves
and it chose "next" each time; the first question took longer than two
minutes while the model loaded, so the wait is five minutes.

## Intended Behavior
Whichever local AI is present decides where "next" goes. It is told the stop,
its summary, the **foundations** it may step back to (earlier stops used
inside this stop's own lines), and what the reader did recently of their own
accord (more, why, code, skip, and its own earlier moves). It never asks the
reader anything and never tests them. It answers one line: NEXT, BACK n, MORE
or SUMMARY. A step back is remembered, and the reader's next "next" returns
to where they were. Any AI fits that takes two texts and returns one: the
default speaks to the llama.cpp server through `libs/llama-chat-client.lua`,
pointable at ollama or another server; `--guide-model` plugs in any other
(tests plug in stand-ins).

Every reader action and guide move is noted, encrypted, in the guide's room
(065e, 065f). An answer that cannot be used — no move in it, a step back to a
stop not offered, a server that did not answer — is shown to the reader, who
chooses; the program never chooses in the guide's place. A guide asked for but
unable to start is an error, not a quiet walk without one.

## Suggested Implementation Steps
1. Foundations from the map's use lists.
2. Standing instructions, the moment's text, reply parsing to a move.
3. The walk's "next" asks the guide; step back and return; trail notes.
4. Tests with stand-ins: steps back when struggling, returns, notes only
   encrypted, unusable answer hands back, wrong step back refused, no server is
   an error, room in order after.

## Decided against
- Picking "next" when the guide's answer is unusable: that would be the
  program deciding in the guide's place, silently.
- Asking the reader a question to judge understanding: ruled out until "the
  future will decide".
