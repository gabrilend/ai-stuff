# 405 — Send misfits back like compiler errors

phase 4, the thinkers

## Current behavior

The fit check (103) can measure a frame and write a report. Nothing gives
the report to a model.

## Intended behavior

The owner's words: "The LLM is provided this knowledge, and if their output
doesn't fit it is returned mechanically and run again with a description of
why. Like a compiler error."

The ask-until-it-fits step:

1. Ask the backend with the prompt (404).
2. Split the reply into thought lines and run the fit check against the
   share.
3. If it fits, return the lines.
4. If not, add two turns to the conversation, the model's reply
   (`assistant`) and the fit report (`user`), and ask again.
5. After the last allowed try (a setting), give up on this turn with an
   error. Never trim.

Counted per turn: tries used, and for each failed try the kind of problem
(too wide, too many lines, both). Over a run these say how well each model
and backend respects the box, which is one of the phase-4 demo's main
numbers.

## Suggested implementation steps

1. The loop, with a stand-in backend in tests that answers from a script
   (too wide, then fits; never fits).
2. Then against `local-llama` with a tiny box, to see a real model being
   corrected.

## Related documents

- `docs/display-box.md`, "The fit check"
- `docs/datapath-thinker.md`, step 5

## Blocked by

103, 401, 404.

## Blocks

406.
