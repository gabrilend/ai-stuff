# Datapath: one turn on a voice

A turn is what a mini-computer does each time a new canvas arrives: "the
minicomputer's r-mail inbox will be set up to have a hook script upon
receive that executes a turn of the LLM machinery ... Then, to write the
output to the outbox with the correct formatting and such."

## One turn

    tmp/shared-memory/turn/waiting
       │
       1. read the canvas (version N, size, project, mode)
       │
       2. make sure the project clone is at the canvas's commit
       │     (docs/datapath-looking-into-the-project.md)
       │
       3. read the endpoints file; pick this voice's endpoint
       │
       4. build the conversation
       │
       5. ask the model ──► the model may call look(...) ──► pieces of code
       │        ▲                                              │
       │        └────────────── answered, ask again ◄──────────┘
       │
       6. fit check ── fails ──► report back to the model, ask again (N tries)
       │ fits
       ▼
       7. write outbox/canvas (base: N), turn counter + 1

1. **Read the canvas** with the canvas reader (`docs/canvas-format.md`).
2. **Project clone.** The `project:` header names the project and commit
   being worked on. If this voice's clone is behind, it is fetched first.
3. **Endpoint.** `endpoints` is read again (`docs/endpoints.md`), so a
   change made while running takes effect on this turn.
4. **Conversation.** From an instruction file in `input/`, filled in:
   - who this voice is, and that two others edit the same canvas;
   - the rules: the canvas is real and stays on screen. Change as little as
     possible, single words before sentences, and keep what still matters
     while fitting in what is new;
   - the canvas size and the change budgets (`docs/fit-check.md`);
   - the look tool, and how to ask for focused or broad results;
   - the canvas itself, exactly as it is.
5. **Ask.** The model may answer with a look call instead of a canvas.
   The call is answered (`docs/datapath-looking-into-the-project.md`), the
   result is added to the conversation, and the model is asked again. The
   number of look calls per turn is limited by a setting.
6. **Fit check.** The reply is the whole edited canvas. It is checked
   against the size and the budgets. On failure the compiler-style report
   goes back to the model, up to a set number of tries. When the tries run
   out, the turn sends nothing and counts a give-up. A reply is never trimmed
   to make it fit.
7. **Write.** Headers (`voice`, `turn`, `base: N`, `size`, `written`), a
   blank line, the rows, an empty marks section. It is checked by reading it
   back with the canvas reader, then written under a temporary name and
   renamed over `outbox/canvas`.

## One turn at a time

The turn hook only leaves the newest canvas in `turn/waiting` and starts the
turn runner if it is idle (`docs/datapath-round-trip.md`, steps 3–4). A
canvas that arrives during a turn waits. Two that arrive during a turn: the
older is replaced. After its turn the runner always starts from the newest
canvas, never from one it skipped.

## What the turn counts

In the log and the goodbye receipt (`tmp/shared-memory/` and `output/` on
the voice): turns run, canvases sent, unchanged turns, look calls (by focus),
fit retries by kind, give-ups, endpoint used, seconds and tokens per turn.
