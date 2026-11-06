# 105 — The monorepo, mapped

| | |
| --- | --- |
| Phase | 1 — The model, and the tools that read it |
| Blocked by | 102, 103 |
| Blocks | — |
| Reads | [what blocked means](../docs/004-what-blocked-means.md) |

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
