# Datapath: one turn on a voice

A turn is what a mini-computer does each time a new canvas arrives: "the
minicomputer's r-mail inbox will be set up to have a hook script upon
receive that executes a turn of the LLM machinery ... Then, to write the
output to the outbox with the correct formatting and such."

## One turn

    tmp/shared-memory/turn/<voice>/waiting
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
       6. fit check ── fails ──► report back to the model, ask again (no limit)
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
   - the canvas size and the recommended change counts (`docs/fit-check.md`);
   - the look tool, and how to ask for focused or broad results;
   - the canvas itself, exactly as it is.

   Built in issue 403 (`src/049-turn-prompt.lua`, `input/turn-instructions`):
   - The conversation is two turns. The **system** turn holds who the voice
     is, the rules, the size and the recommended counts, the look call's form
     and an example of the exact shape (`src/027-exact-shape.lua`).
   - The **user** turn holds the version, the last turn's advisory note, the
     words this voice's last edit cut, and the canvas.
   - The canvas sits inside a ruler: two lines of column numbers above it
     (three past 100 columns), the row number to the left of each row, and a
     `|` at each end of each row, showing the width. The prompt says the
     ruler is not part of the canvas, and a reply that copies it is reported
     like any other fit problem (`ruler`, `docs/fit-check.md`).
   - The look call is one line, `look focused: WORDS` or `look broad: WORDS`,
     recognised in the reply.
   - The reference prompt for a fixed canvas is
     `assets/test-prompts/01-turn-prompt.expected`.
5. **Ask.** The model may answer with a look call instead of a canvas.
   The call is answered (`docs/datapath-looking-into-the-project.md`), the
   result is added to the conversation, and the model is asked again. The
   number of look calls per turn is limited by a setting.
6. **Fit check.** The reply is the whole edited canvas. It is checked
   against the size; the change counts become an advisory note, never a
   refusal. On failure the compiler-style report goes back to the model, with
   a too-large reply shown cut at the edge, and the model is asked again with
   no limit on tries ("it will just keep spinning until it gets it right").
   The cut version is never published.
7. **Write.** Headers (`voice`, `turn`, `base: N`, `size`, `written`), a
   blank line, the rows, an empty marks section. It is checked by reading it
   back with the canvas reader, then written under a temporary name and
   renamed over `outbox/canvas`.

## One turn at a time

The turn hook only leaves the newest canvas in `turn/<voice>/waiting` and
starts the turn runner if it is idle (`docs/datapath-round-trip.md`, steps
3–4). A canvas that arrives during a turn waits. Two that arrive during a
turn: the older is replaced. After its turn the runner always starts from
the newest canvas, never from one it skipped. (Built in issue 304:
`src/037-turn-hook.lua`, `src/038-turn-runner.lua`.)

The lock is the directory `turn/<voice>/lock`, holding `pid`: the runner's
process number and the time the system started that process. It is made
under another name with `pid` already inside, then renamed into place, so
it appears whole or not at all and two runners can never both hold it. A
lock whose process is not running, or whose number now belongs to a process
started at another time, was left by a runner that died: it is moved aside,
removed, and the runner logs `cleared a lock left by process N, which is not
running`.

The runner runs the turn as a program, named by `turn` in
`input/turn-runner`:

    <turn> --dir ROOT --voice NAME --turn N --canvas FILE --out FILE

It reads the to-voices canvas in `--canvas` and writes the voice's canvas
to `--out`. The runner reads that back and checks its voice, turn, base and
size before anything is sent. A turn that changed no row sends nothing and
keeps its turn number; a turn that fails (non-zero exit, nothing written,
wrong headers) sends nothing either. The turn number grows by one for every
canvas sent. In phase 3 the turn is the stand-in (`scripts/stand-in-turn`),
which writes one word from `input/stand-in-turn` into the voice's third of
the canvas; the real turn (issue 405) replaces it in that setting.

## What the turn counts

In the log and the goodbye receipt (`tmp/shared-memory/` and `output/` on
the voice): turns run, canvases sent, unchanged turns, look calls (by focus),
fit retries by kind, endpoint used, seconds and tokens per turn.

Built so far (issue 304): the runner's receipt `output/goodbye-turn-runner-
<voice>` counts `turns-run`, `canvases-sent`, `unchanged-turns`,
`turns-failed` and `canvases-refused` (a waiting text that is not a
canvas); its log gives the seconds of every turn. Each step is also a line
in `tmp/shared-memory/turn/<voice>/events`, `<unix time, ms> <event>
<version> [turn]`, with the events `received`, `replaced`, `taken`, `sent`,
`unchanged`, `failed`, `refused` and `busy`, which the rehearsal (305)
reads for its timings. The rest come with the real turn (405).
