# Phase 5 Progress — Looking into the project

## Goals
The project being worked on, cloned onto each voice (in RAM if it fits),
the embedding index contract and its build guide, and the look tool that
answers focused or broad. Ends with one question asked at five focus
levels.
(`docs/roadmap.md`, phase 5)

Counts of done and open issues:
`/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/guide-feature -m`

## Completed Issues
- **501, the project clone, in RAM if it fits** (2026-11-05):
  - `src/058-project-clone.lua` (`scripts/project-clone`) brings each
    voice's clone of the project the canvas names to the commit it names,
    at the start of every turn. The projects and where they come from are
    in `input/project-clone`.
  - One commit at a time, only the project's folder, only its files: about
    7 MiB for guide-feature's commit of the 735 MiB monorepo.
  - In RAM (`/dev/shm`) when it is a tmpfs and the project with its working
    room fits a share of the memory available; on disk otherwise, and the
    turn's log says which and why. A project switch keeps the earlier clone.
  - Tested by itself and in the rehearsal, where each voice clones once and
    fetches a commit made while it runs. SSH to kuvalu and the real
    monorepo are for the owner's machine.
- **502, the embedding index: contract and build guide** (2026-11-05):
  - `docs/embedding-index-build-guide.md` says how to give a project an
    index; it was followed for guide-feature, and the contract is agreed.
  - `src/060-embedding-index.lua` holds the piece and name rules and the
    index's files, on its own so other projects can copy it.
    `scripts/build-embedding-index` builds guide-feature's index from the
    checked-out commit; `scripts/check-embedding-index` says whether it can
    be used; `scripts/install-index-hooks` keeps it built after every
    commit, pull and checkout.
  - guide-feature's own index, built against a stand-in embedding model, is
    about 1,070 pieces. The real model's index on kuvalu is for the owner's
    machine.
- **503, the look tool, focused or broad** (2026-11-05):
  - `src/064-look.lua` answers every look call in a turn: the pieces of
    the project nearest the model's words, from the voice's clone and its
    embedding index, four in a row for `look focused`, twelve spread from
    nearest to farthest for `look broad` (`input/look`), with their source
    text, up to 2000 tokens a look.
  - The clone keeper copies kuvalu's index into each voice's clone when it
    is at the clone's commit; the voices build none. The embedder travels
    in the canvas, as one more endpoint line.
  - A look with nothing to show tells the model why and is counted; it
    never shows other files instead.
  - Tested against guide-feature's own index at a pinned commit:
    "canvas width" at focus 1, 0.5 and 0 gives three visibly different
    sets, kept as reference files. The real models' numbers are for the
    owner's machine.
- **504, the phase 5 demo** (2026-11-05): `issues/completed/demos/phase-5-demo`
  (also `./run-phase-demo 5`).
  - Builds kuvalu's side here: guide-feature's own code in a one-commit
    monorepo, and its index. A voice's clone of it is made in RAM, with
    the index copied in.
  - Asks one question ("canvas width", or `--about`) at focus 1, 0.75,
    0.5, 0.25 and 0: 4 to 12 pieces, each list with a similarity chart and
    a strip of where the pieces sit among all 1,100 or so, so the reach
    can be seen widening; then the focused answer as the model reads it.
  - Runs the rehearsal with the real turn in all three voices, whose
    stand-in models look focused, then broad, then not, and shows every
    look from the turns' logs (about what, at what focus, what came back),
    one answer as its model read it, and where each voice's clone went,
    RAM or disk, and why.
  - The test checks the output against the look tool's own answers, the
    turns' logs and receipts, and a run where no clone fits in RAM.

## Phase 5 is done here, apart from the real models

501–504 are done. Each voice keeps a clone of the project the canvas names,
in RAM when it fits; kuvalu's embedding index of the project is built after
every commit and copied into each voice's clone; and a voice's model can
look into the project, focused or broad, before it writes. The roadmap's
goal for phase 5, "the same question asked at several focus levels, then
a turn that used the look tool", is met here against stand-in models.

Left for the owner's machine:
- **SSH from each voice to kuvalu by key, and git 2.25 or later on the
  voices** (501; issue 701's survey).
- **The first real clone of the monorepo** on an fg-sora, and `ram-share`
  and `working-room` set for those machines.
- **`scripts/install-index-hooks` on kuvalu**, once `kuvalu-embed` runs
  (401a), and the first real index.
- **The real embedding model**: its name in `endpoints`, and the look's
  `budget`, `nearest`, `spread` and `curve` tried with it and the real chat
  model.
- **The demos against the real servers.**

