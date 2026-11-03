# 501 — The project clone, in RAM if it fits

phase 5, looking into the project

## Current behavior

Nothing exists. The canvas carries a `project:` header (303), and the turn
ignores it.

## Intended behavior

The owner: "whatever we're working on at the time", and "I think we'd git
clone a project into the mini-computer if we were gonna work on it. To RAM
if it fits."

The clone keeper, called at the start of every turn:

- reads the project name and commit from the canvas;
- if this voice has no clone of that project, clones it from kuvalu over SSH
  (allowed between the four machines);
- places the clone in `tmp/` (RAM) when the project's size, plus room for
  the turn's own working memory, fits within a share of free memory (a
  setting). Otherwise it goes on disk. The choice is logged, because the disk
  is the slower path;
- if the clone is behind the commit, fetches and checks it out;
- keeps one clone per project, so returning to an earlier project is a
  fetch, not a fresh clone, while it is still in RAM.

Which repository to clone from, for a project name, comes from a list in
`input/turn` (name to SSH address on kuvalu).

## Suggested implementation steps

1. Size measurement on kuvalu (`git count-objects -vH` on the source), sent
   in the header or measured after the first fetch.
2. Clone, fetch, checkout, placement.
3. Tests in the rehearsal: first clone, a newer commit, a project switch, a
   project too big for its RAM share.

## Related documents

- `docs/datapath-looking-into-the-project.md`
- `docs/network.md`

## Open questions

- Do the mini-computers have `git`? (`docs/open-questions.md`, 1)

## Blocked by

None.

## Blocks

503, 704.
