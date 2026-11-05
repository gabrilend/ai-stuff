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
