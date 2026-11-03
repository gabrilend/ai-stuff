# 105 — The monorepo, mapped

| | |
| --- | --- |
| Phase | 1 — The model, and the tools that read it |
| Blocked by | 102, 103 |
| Blocks | — |
| Reads | [what blocked means](../../docs/004-what-blocked-means.md) |

## Current behavior

The board has only the bakery to rank.

## Intended behavior

The monorepo this project lives in has the shape the vision describes: many
projects, one person who merges, and a long queue of open pull requests, many
stacked on others. A tool reads that queue and writes it as an org map: each
open pull request a `work` box held by the person who merges, each stacked
pull request wired to the one it is built on, each project a `role` that waits
on its open pull requests, and a short hand-kept list of open questions as
work boxes too. The board then says which merge or answer frees the most.

## Suggested implementation steps

1. A Bash script that lists the open pull requests through the GitHub REST
   API and the projects each touches, into a plain tab-separated snapshot.
2. A Lua converter from the snapshot (and the questions list) to `org.map`
   and `org.state`, deterministic, so a re-run with the same input is no diff.
3. Commit one snapshot and its map as the example, and the board it gives.
4. Tests on a small fixture snapshot: stacks wire up, a pull request into a
   branch nobody has open is waiting on outside, the map validates.
5. The phase 1 demo: the board over the monorepo.

## What Happened

Built as `scripts/list-open-pull-requests` (the snapshot, by GitHub's REST
API, reading only), `src/012-monorepo-map.lua` (snapshot and questions to
`org.map`), and `./map-the-monorepo`, which regenerates the map, validates it,
writes the board and the page, and prints the top of the board. The committed
example is the queue as of 2026-11-03: 184 open pull requests, three open
questions, sixteen projects; 80 pull requests can be merged now, and the top
of the board is a merge that 22 boxes wait behind. Decisions:

- **A project is a role meaning "its next round of work"**, which waits on
  every open pull request touching it, because the next round branches from
  main. Projects are held by the builder; pull requests and questions by the
  owner, who merges and answers.
- **A pull request built on a branch that no open pull request carries is not
  blocked**: its base is written as a fixed value naming the branch, since
  nothing stops it but retargeting onto main. (The issue's first draft had it
  waiting on an outside party; that would have ranked a non-blocker on the
  board.)
- **Which projects a pull request touches** is read from its changed files'
  top-level directories, not its title.
- **The questions are a hand-kept file in the shared grammar**, each citing the
  project file that says it is open. Only three are listed — the ones whose
  own files say they wait on the owner — rather than a guess at every open
  question in every project.
- **The snapshot is committed with its date**, and a test checks that the
  committed map, board and page are exactly what that snapshot makes, so a
  regenerated example never drifts unnoticed.
- **The board gained `--says`**, printing each row's description under it,
  since a board of pull request numbers is unreadable without titles.
