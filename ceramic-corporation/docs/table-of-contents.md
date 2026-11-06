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
├── run-tests ................................. Every test, under LuaJIT and Lua
│                                               5.4, and every example validated.
│
├── src/ ...................................... The tools. Numbered, each with a
│   │                                           companion .info.md.
│   ├── 007-org-reader ........................ The one reader, and the validator.
│   ├── 008-blocked-board ..................... owes, frees, reach.
│   └── 010-proposals ......................... Status, kinds, affected, rules;
│                                               the map edited as text.
├── tests/
│   ├── 009-the-map-and-the-board ............. One refusal per rule code; the
│   │                                           board against document 004.
│   └── 011-proposals ......................... Every ruling of document 003.
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
│   └── bakery/ ............................... The worked example every document
│                                               uses: a map, a state, two proposals.
│
└── issues/ ................................... Phase-numbered issue files.
    ├── phase-N-progress.md
    └── completed/
```
