# Table of contents

    wow-reports/
    |
    +-- notes/
    |   `-- 000-vision.md ................ what was asked for, in the asker's
    |                                      words, and the argument with its
    |                                      closing line
    |
    +-- docs/
    |   +-- table-of-contents.md ......... this file
    |   +-- 001-where-the-numbers-live.md  survey of every source worth
    |   |                                  harvesting, what it costs, and why
    |   |                                  one obvious one is skipped
    |   +-- 002-open-questions.md ....... every decision, settled ones kept
    |   |                                  beside their alternatives and
    |   |                                  outstanding ones ordered by what
    |   |                                  they block
    |   +-- 003-roadmap.md .............. the ten phases and what each is a
    |   |                                  cluster of
    |   +-- 004-the-archive-and-its-
    |   |   branches.md ................. where fetched bytes live, the two
    |   |                                  branches, licence gating, and why
    |   |                                  files are small and specific
    |   +-- 005-the-shape-of-a-fact.md .. the record format - one entity, its
    |   |                                  whole history folded inside it as
    |   |                                  per-build changes
    |   `-- 006-what-this-is-actually-
    |       for.md ...................... the destination: a floating commander
    |                                      directing many bots, combat resolved
    |                                      by prediction, and what that makes
    |                                      the rest of the project
    |
    +-- issues/
    |   +-- 101..105 ................... phase 1, the patch spine
    |   +-- 201..207 ................... phase 2, the harvester
    |   +-- 801..806 ................... phase 8, emission to the server
    |   `-- completed/ ................. nothing yet
    |
    +-- src/ ........................... nothing yet
    +-- libs/
    +-- assets/
    `-- tmp -> /tmp/wow-reports ........ scratch; executable tier, with
                                         shared-memory/ inside it pointing at
                                         /dev/shm/wow-reports for logs and
                                         other artefacts that never touch a disk

## Phases

Clusters of functionality, numbered by how much stands on top of them. The last
issue finished may well belong to phase one.

| Phase | Cluster | Issues written |
|---|---|---|
| 1 | The patch spine - every version the game has had, and the questions asked of that timeline | yes |
| 2 | The harvester - fetching politely, archiving permanently, splitting into small specific files | yes |
| 3 | Extraction - archived bytes into typed facts stamped with a build | not yet |
| 4 | The viewer - the timeline scrubber and the expansion meta views | not yet |
| 5 | The arithmetic model - uptime averages, no clock, cheap | not yet |
| 6 | The event simulator - a clock, a queue, a priority list; the laboratory instrument | not yet |
| 7 | The correlation measurement - the gap between the two models, per specialisation | not yet |
| 8 | Emission to the server - the archive becomes reversible patches | yes |
| 9 | Combat substitution - the cheap model resolves fights at game speed | not yet |
| 10 | The commander - mostly the server project's business; recorded so earlier phases can be checked against it | not yet |
