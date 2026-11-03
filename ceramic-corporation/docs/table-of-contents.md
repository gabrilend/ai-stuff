# Table of Contents

Everything in this project, in reading order. Issues are found through
[the roadmap](006-roadmap.md); source files through their companion `.info.md`
pages.

File indices count up across the whole project from a single counter at
`.file-index-counter`, so the numbers are a reading order, not a per-directory
sequence.

```
ceramic-corporation/
│
├── README.md ................................. What this is, in one page.
├── LICENSE ................................... The GNU Affero General Public
│                                               License, version 3, verbatim.
├── COPYING.md ................................ What the AGPL asks of you.
│
├── validate-org .............................. Checks an org directory against
│                                               every rule, naming each by code.
├── blocked-board ............................. Ranks what an org waits on by how
│                                               much depends on it.
├── apply-proposal ............................ Says whether a change may be applied,
│                                               shows its diff, and applies it.
├── org-page .................................. An org as one static HTML5 page.
├── map-the-monorepo .......................... The monorepo's own queue of pull
│                                               requests, as an org, ranked.
├── replay-history ............................ Checks that first.map and the applied
│                                               proposals make org.map exactly.
├── run-phase-demo ............................ Runs a phase's demo.
├── run-tests ................................. Every test, under LuaJIT and Lua
│                                               5.4, and every example validated.
│
├── src/ ...................................... The tools. Numbered, each with a
│   │                                           companion .info.md.
│   ├── 007-org-reader ........................ The one reader, and the validator.
│   ├── 008-blocked-board ..................... owes, frees, reach.
│   ├── 010-proposals ......................... Status, kinds, affected, rules;
│   │                                           the map edited as text.
│   ├── 012-monorepo-map ...................... A snapshot of the queue, as a map.
│   ├── 013-org-page .......................... The static page.
│   └── 015-history ........................... The history replayed.
├── tests/
│   ├── 009-the-map-and-the-board ............. One refusal per rule code; the
│   │                                           board against document 004.
│   ├── 011-proposals ......................... Every ruling of document 003.
│   ├── 014-the-monorepo-and-the-page ......... The queue as a map; the page; every
│   │                                           generated example against its
│   │                                           generator.
│   └── 016-the-history ....................... Every way a history can fail to
│                                               explain a map, by its code.
├── scripts/
│   └── list-open-pull-requests ............... The queue, from GitHub's REST API.
│
├── notes/
│   └── vision ................................ Where all of this came from, in the
│                                               author's own words. Read first.
│
├── docs/
│   ├── 001-what-this-is ...................... The idea, the vocabulary, and what
│   │                                           soramech is as this project reads it.
│   ├── 002-the-org-map ....................... The data model, exactly: the grammar,
│   │                                           the map, the state, what fed and
│   │                                           blocked mean. Every rule has a code.
│   ├── 003-how-a-change-is-accepted .......... Proposals, applying them, kinds of
│   │                                           change, who is affected, the rules,
│   │                                           and the vision's questions ruled on.
│   ├── 004-what-blocked-means ................ The blocked board: owes, frees, reach.
│   ├── 005-open-questions .................... What is left, each with a working
│   │                                           ruling.
│   ├── 006-roadmap ........................... Two phases and their issues.
│   └── table-of-contents ..................... This page.
│
├── examples/
│   ├── bakery/ ............................... The worked example every document
│   │                                           uses: a map, a state, two proposals,
│   │                                           and its page.
│   ├── workshop/ ............................. An org that keeps a history: its
│   │                                           first map, two applied changes and
│   │                                           an open one.
│   └── monorepo/ ............................. This repository's queue of pull
│                                               requests as an org: the snapshot and
│                                               questions it is made from, the map,
│                                               the board, the page.
│
└── issues/ ................................... Phase-numbered issue files.
    ├── phase-N-progress.md
    └── completed/
        └── demos/ ............................ One per phase, run by run-phase-demo.
```
