# Open questions

Every question met while designing guide-feature. A question stays here until
it is worked through with the owner. Its answer is then written into the
document it changes, and the entry moves to "Answered" with a pointer. The
project is in progress, not finished, while any question here is open.

Most valuable first.

## Open

1. **Which C library and which tools do the mini-computers have?** glibc or
   musl, and whether `curl` and `git` are present. The llama.cpp client uses
   `curl`; the project clone uses `git`. The owner has given permission to
   look; the survey (`issues/701`) answers it once it is run. Since issue
   501 (2026-11-05) the clone needs `git` 2.25 or later on each voice, for
   sparse checkout and the blob filter, and SSH from each voice to kuvalu
   by key.
2. **Where should the embedding index builder's guide live, given that
   projects should not depend on each other?** If it lives in delta-version,
   each project copies the builder into itself (`docs/vendored-code.md`).
   Should it be built first for guide-feature itself, so phase 5 has an index
   to test against? `docs/embedding-index-contract.md`. The owner: "not
   sure. let's come back to it later." Answered for now in 502
   (2026-11-05), until the owner decides: the guide is
   `docs/embedding-index-build-guide.md`, in guide-feature, written so it
   can move unchanged; another project copies `src/060-embedding-index.lua`
   into itself, as vendored code. guide-feature's own index was built first.
3. **The tool call's form.** llama.cpp supports OpenAI-style tool calls when
   its server runs with its chat templates switched on (`--jinja`). Is
   kuvalu's server started that way, or should the look call be a plain line
   in the reply that the turn recognises? `issues/403`. Answered for now
   in 403 (2026-11-05), until the owner decides: a plain line in the reply,
   `look focused: WORDS` or `look broad: WORDS`. It works whether or not the
   server runs with `--jinja`.
4. **Characters or terminal columns?** Some characters take two columns in
   a terminal. If voices may write them, the fit check and the blit must
   count columns. `docs/fit-check.md`.
5. **Building the Apple Watch app needs a Mac with Xcode.** Is one
   available? `issues/902`.
6. **Should the voices know who the others are?** It changes the first
   lines of the prompt, and probably how the voices behave toward each
   other's words. `issues/403`. Answered for now in 403 (2026-11-05), until
   the owner decides: each voice is told that two other voices edit the same
   canvas, not their names. That wording is in `input/turn-instructions`,
   where the owner can change it.
7. **Can the person watching write onto the canvas too?** The vision says
   "each part of it can be edited". kuvalu could blit the person's edits as
   a fourth voice. `docs/architecture.md`.

## Answered

- Which collision rules come after the whole-word rule: **`fade-fragments`,
  `keep-fragments` and `push-aside`** ("these sound like decent options").
  The owner wants to see "confusion, as it flips back and forth. Indecision
  is valid. But, it should coalesce to a stable state over time, because the
  LLMs are encouraged to change as little as possible."
  `docs/datapath-blit.md`, "Collision rules".
- How many words a voice may change: **as many as it likes; the limit is
  soft.** "as many as it'd like, but it's recommended to change fewer, and
  focus on ... 'operative words' like 'very' being replaced to 'not very'".
  `docs/fit-check.md`.
- Whose name goes on a change in distill mode: **no one's in particular;
  credit is not tracked.** "The provenance is inherently melded together like
  melting two candles to each other." `docs/datapath-blit.md`, "distill".
- The way in from outside: **a mailbox in the display program, using
  rmail's own encryption**. "The display program (on your phone, computer,
  whatever) will have a mailbox and display whatever it receives." Whether
  the phone collects or kuvalu pushes, and how often (rmail's 30-second
  pacing), "we will tune these numbers as we implement." `docs/network.md`.
- Whose window sets the size: **each watched screen gets its own canvas**,
  refreshed largest first, smallest last (`round`); or all at once
  (`asynchronous`); or one canvas at the smallest watched size, centred and
  enlarged up to a maximum on the bigger screens (`smallest`). One mode at a
  time. `issues/205`.
- Is a cut reply ever published? **No. The turn has no try limit; it
  "will just keep spinning until it gets it right."** `docs/fit-check.md`,
  `issues/404`.
- How a plain web browser watches: **through the HTTP canvas server; the
  canvas is encrypted in transit and decrypted in the page's JavaScript.**
  `docs/network.md`, `issues/204`, `issues/803`.
- Where a browser gets the key: **after the `#` in the page's address**,
  which browsers never send to the server; each device bookmarks it once.
  How it decrypts on plain HTTP: **with AES-256-GCM in JavaScript, copied
  into the page**, because the browser's Web Crypto is missing there.
  `docs/network.md`, `issues/803`.
- Who writes on which screen's canvas: **every voice, on every canvas.
  "one canvas, one screen. Should be the same subject they're painting, but
  with two separate brushsizes on two separate papers."** `issues/205`.
- Whose AES-256-GCM goes into the page: **noble-ciphers, copied in**.
  `docs/vendored-code.md`.
- Is the browser's key separate from the rmail secrets: **yes, and unique to
  each session.** A viewer without a key in the address is asked for a
  password, set up on the server beforehand. `docs/network.md`.
- What crosses in plaintext when a browser uses a password: **only the page
  and its prompt. The password never leaves the browser**; the browser turns
  it into the viewer's key, and the server sends the session's fresh key
  locked with it. `docs/network.md`.
- Should the canvas history survive a restart? **No.** It stays in RAM, and
  after a reboot each voice's first canvas is refused and it is sent the
  current version. `docs/datapath-round-trip.md`, `issues/203`.
- Can rmail's public-address lookup and router port-mapping be turned off?
  **They are switches the user turns on or off as they please.**
  `docs/network.md`, `issues/702`.
- Should kuvalu tell each voice which endpoint to use? **Yes** ("I guess
  so?"): an `endpoint` header in the canvas kuvalu sends, and only kuvalu
  keeps the `endpoints` file. `docs/endpoints.md`, `docs/canvas-format.md`.
  (2026-11-05, issue 402: one line per voice in an `endpoints:` section
  instead of one header, so each voice can have its own endpoint.)
- Should the voices argue their changes through their mailboxes? **Not
  planned.** "that's not necessary, and I worry it might lead to all of them
  speaking the same words or having the same voice. It's better if they drift
  a bit, but stay focused." `docs/roads-not-taken.md`.

- The whole-word rule: **yes, a word that loses part of itself is blanked
  whole, as the default, with other collision rules to play with**.
  `docs/datapath-blit.md`, "Collision rules".
- How the phone, the watch and outside browsers reach the canvas (first answer,
  since narrowed to a mailbox in each display, below): **one
  forwarded port to kuvalu's canvas server only, "a narrow cause-way"**.
  `docs/network.md`.
- Using words-pdf's llama.cpp server: **no. This project runs its own,
  built from its own clone with words-pdf's local checkout as upstream. No
  project depends on another; reused code is copied in and refreshed from
  its local upstream**. `docs/vendored-code.md`, `docs/endpoints.md`.

- Inbox port: **1223** (111213 is beyond the 65535 limit).
  `docs/architecture.md`.
- How a shared page survives rmail's author-only edits: **hooks hand
  arrivals to a running Lua program that decides**. `docs/architecture.md`.
- What listens on the mini-computers' ports: **nothing yet**. Phase 7.
- The display module: **a protocol first, then Lua window, terminal view,
  HTML page, Android app, Apple Watch app**. `docs/canvas-protocol.md`.
- What the page is: **one canvas, all voices blitting to the same grid; only
  changed words are written, partly-overwritten words are blanked, changed
  sentences are marked**. `docs/datapath-blit.md`.
- How kuvalu merges: **two modes, `newest` (original) and `distill`**.
  `docs/datapath-blit.md`.
- What starts a voice's turn: **kuvalu's canvas arriving**.
  `docs/datapath-round-trip.md`.
- What counts as changed: **compared with the version the voice started
  from**. `docs/datapath-blit.md`.
- Canvas size: **the same for every voice; all rows and columns**.
  `docs/fit-check.md`.
- Which project: **whatever is being worked on, cloned onto each voice, in
  RAM if it fits**. `docs/datapath-looking-into-the-project.md`.
- How context is chosen: **a look tool call with an embedding priority,
  focused to broad**. `docs/datapath-looking-into-the-project.md`.
- Where the embeddings are built: **by per-project development tooling,
  perhaps delta-version, with a guide; guide-feature only reads them**.
  `docs/embedding-index-contract.md`.
- Remote processing: **llama.cpp endpoints listed in a project-root file,
  selectable at runtime; on kuvalu for now**. `docs/endpoints.md`.
- The network: **the four accept only each other; outside providers only as
  replies to connections we opened**. `docs/network.md`.
- rmail's timing: **adjustable per implementation, in the Lua scripts**.
  `docs/rmail-constraints.md`.
