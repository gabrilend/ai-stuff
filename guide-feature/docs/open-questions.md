# Open questions

Every question met while designing guide-feature. A question stays here until
it is worked through with the owner. Its answer is then written into the
document it changes, and the entry moves to "Answered" with a pointer. The
project is in progress, not finished, while any question here is open.

Most valuable first.

## Open

1. **Which collision rules should be built after `blank-whole`?** Six are
   designed: `blank-whole`, `fade-fragments`, `keep-fragments`,
   `refuse-cut`, `push-aside`, `blank-sentence`, plus the tell-the-voice
   switch. Each one built must be tested beside the others.
   `docs/datapath-blit.md`, "Collision rules".
2. **Does the causeway need a key, and encryption?** The canvas server is
   the one program reachable from outside. Without a key, anyone who finds
   the port can read the canvas. Without HTTPS, the canvas crosses the
   internet as readable text. Which port does the router forward?
   `docs/network.md`, "Keeping the causeway narrow".
3. **How many words may change per turn, and how many whole sentences may be
   rewritten?** These are the change budgets in the fit check. Strict budgets
   enforce "prioritize editing single words over changing sentences". Too
   strict, and a voice can never bring in a new idea. `docs/fit-check.md`.
4. **In distill mode, whose name goes on a change: kuvalu's, or the voice
   whose idea it came from?** The second needs the distiller to say where
   each change came from. `docs/datapath-blit.md`.
5. **How should the canvas size change?** Every voice's words sit at fixed
   rows and columns, so a smaller canvas crops them and a larger one leaves
   space. Options: size fixed per run; size changes only between runs; or the
   canvas resized with all marks cleared and voices told. `issues/205`.
6. **Should the canvas history survive a restart?** It lives in RAM. Without
   it, after a reboot every voice's base is unknown and their first canvases
   are refused. `docs/datapath-round-trip.md`.
7. **Which C library and which tools do the mini-computers have?** glibc or
   musl, and whether `curl` and `git` are present. The llama.cpp client uses
   `curl`; the project clone uses `git`. `issues/701`.
8. **Can rmail be told not to look up its public address or map its port?**
   Those requests go to outside services that are not language-model
   providers, which the router rules may block. `docs/network.md`.
9. **Should kuvalu tell each voice which endpoint to use, in the canvas it
   sends, instead of each machine keeping its own copy of `endpoints`?** One
   place to switch versus one more header. `docs/endpoints.md`.
10. **Where should the embedding index builder's guide live, given that
    projects should not depend on each other?** If it lives in delta-version,
    each project copies the builder into itself (`docs/vendored-code.md`).
    Should it be built first for guide-feature itself, so phase 5 has an index
    to test against? `docs/embedding-index-contract.md`.
11. **The tool call's form.** llama.cpp supports OpenAI-style tool calls when
    its server runs with its chat templates switched on (`--jinja`). Is
    kuvalu's server started that way, or should the look call be a plain line
    in the reply that the turn recognises? `issues/403`.
12. **Characters or terminal columns?** Some characters take two columns in
    a terminal. If voices may write them, the fit check and the blit must
    count columns. `docs/fit-check.md`.
13. **Building the Apple Watch app needs a Mac with Xcode.** Is one
    available? `issues/902`.
14. **Should the voices know who the others are?** It changes the first
    lines of the prompt, and probably how the voices behave toward each
    other's words. `issues/403`.
15. **Can the person watching write onto the canvas too?** The vision says
    "each part of it can be edited". kuvalu could blit the person's edits as
    a fourth voice. `docs/architecture.md`.

## Answered

- The whole-word rule: **yes, a word that loses part of itself is blanked
  whole, as the default, with other collision rules to play with**.
  `docs/datapath-blit.md`, "Collision rules".
- How the phone, the watch and outside browsers reach the canvas: **one
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
