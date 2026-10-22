# Datapath: how a voice writes its next frame

The thinker is the long-running Lua program on each fg-sora machine. Each
turn of its loop reads the page, gathers context, asks a language model for a
new frame, checks that the frame fits the box, and hands it to rmail. The
language model can run on the fg-sora itself or somewhere else, with the
fg-sora acting as a relay (below).

## One turn of the loop

    inbox/the-page ──► 1. read the page (box, share, every thought)
                           │
    context folder ──► 2. gather random context, up to the budget
                           │
                       3. build the prompt
                           │
                       4. ask the inference backend ──► local model
                           │                        └─► remote model (relay)
                           ▼
                       5. fit check ── does not fit ──► error report ─┐
                           │ fits                                     │
                           │            ◄── ask again, up to N tries ─┘
                           ▼
                       6. write outbox/frame (temporary name, then rename)
                           │
                           └──► back to 1, as soon as it can

1. **Read the page.** The thinker reads `inbox/the-page` in its rmail
   mailbox (`docs/page-protocol.md`). From the header it takes the `share`,
   which is the width and height its frame must fit. Before the first page
   arrives it uses the box from its own input file and an empty page.
2. **Gather context.** The vision asks for "as much other context stuffed in
   ram as they are able. just... random stuff. stuff that's relevant. from
   the project directory. maybe randomly selected". The thinker picks files
   at random from its context folder, using a seed that it records, and adds
   excerpts until the context budget is reached. The budget is the model's
   context length, minus the room the page, the instructions and the reply
   need. Which project the context folder holds, and how its files get onto
   the fg-sora, are open questions (`docs/open-questions.md`).
3. **Build the prompt.** In this order:
   - who the voice is (its name, and that there are two other voices);
   - the rules: the page is real and valid, so the new frame must keep what
     still matters and may add new things, and what it leaves out will fade;
   - the box: "at most W characters per line, at most H lines, one thought
     per line, no line wrapping";
   - the page, as it is;
   - the voice's own previous frame;
   - the gathered context, each excerpt labelled with its file path.
4. **Ask the backend.** See "Inference backends" below.
5. **Fit check.** The reply is split into lines and checked against the share
   by the shared fit checker (`docs/display-box.md`, "The fit check"). If it
   does not fit, the checker's error report and the reply are added to the
   conversation, and the model is asked again, like a compiler handing back an
   error. After the last allowed try the thinker gives up on this turn. It
   sends nothing, its previous frame stays on the page, and the give-up is
   counted. It never trims a reply to make it fit.
6. **Write the frame.** Headers (`docs/frame-format.md`), a blank line, the
   thoughts. Written to a temporary name in `outbox/` and renamed over
   `outbox/frame`. The frame counter is kept in the thinker's state file so a
   restart continues the count. rmail takes it from there
   (`docs/datapath-frame-to-page.md`).

The thinker starts the next turn as soon as it has written a frame. It does
not wait for a new page. It writes "as soon as they are able", and a voice
that thinks faster than rmail carries simply has some frames replaced before
they leave.

## Inference backends: local, or relayed to a remote machine

The step "turn this prompt into a reply" is one entry in a table of backends,
chosen by name in the thinker's input file. Everything else in the loop (the
page, the context, the fit check, the frame numbering, rmail) stays on the
fg-sora. A voice is still its fg-sora machine wherever its words are
computed. The owner's request: "can we add functionality to have the three
mini-computers connect to remote locations to do their LLM processing? Acting
as relay nodes."

| Backend | Where the model runs | What the fg-sora does |
|---|---|---|
| `local-llama` | on the fg-sora, a llama.cpp server on its own loopback address | everything |
| `remote-llama` | a llama.cpp server on another machine, for example kuvalu's GTX 1080 Ti, or a machine elsewhere | relays: builds the prompt, sends it over HTTP, checks the reply |
| `remote-api` | a hosted model service reached over the internet | relays, as above |

Each backend has the same two-part shape:

- **in**: the conversation so far (a list of turns, each a role, `system`,
  `user` or `assistant`, and a text) and the most text to produce (a whole
  number of tokens);
- **out**: the reply text, plus the counts the backend reports (tokens in,
  tokens out, seconds taken).

Each voice may use a different backend, so the three can be compared on one
page.

A backend that fails (no answer, refused, timed out) is an error for that
turn. It is logged and counted, and the thinker tries again on the next turn.
It does **not** quietly switch to another backend. A quiet switch would make
the page look as if one model were speaking when another one was. Whether the
owner wants a declared, ordered list of backends instead is an open question.

Addresses, keys and passwords for remote backends live in a file outside the
repository, which the input file names. When a remote backend is used, the
page and the gathered project files leave the house. With `remote-api`, they
reach a company's servers. Whether that is acceptable, and for which
projects, is the owner's call (`docs/open-questions.md`).

## What the thinker counts

In its goodbye receipt and its log, kept in `tmp/shared-memory/` on the
fg-sora: turns started, frames written, fit retries, fit give-ups, backend
failures, files sampled, the seed, and per-backend seconds and tokens.
