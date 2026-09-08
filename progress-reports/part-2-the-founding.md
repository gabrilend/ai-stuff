# 29,157 Files

*Part 2 · 15 December 2025 – 12 January 2026*

Everything enters version control in one commit. Two days later the repository has a program that splits an issue into sub-issues and hands them to an assistant, and a rule about fallbacks that the next eight months keep applying.

| | |
| --- | --- |
| issues written | 597 |
| completed | 261 |
| projects | 7 |

## The window

The window opens with the repository's first commit and closes on 12 January, four days before the next stage begins.

**The first commit is 29,157 files and 10,894,824 lines**, titled *Initial commit: AI project collection*. It is the fourteen weeks of Part 1 arriving at once, plus every library those projects had copied into themselves. Ten weeks later, 2,349 of those library files come back out again in favour of install scripts — the two events are the same decision made twice, once by default and once deliberately.

After that, two threads run: the Warcraft III engine takes 357 of the window's 597 new issue files, and the tooling that manages the repository takes 70.

**Commits per day.** 15: 1, 16: 46, 17: 50, 18: 17, 19: 2, 20: 3, 21: 18, : 0, 23: 46, : 0, 25: 12, 26: 6, 27: 55, : 0, 29: 23, 30: 12, 31: 30, 01: 9, 02: 14, : 0, 04: 34, 05: 4, : 0, 07: 22, 08: 22, 09: 17, 10: 13, 11: 4, 12: 8.

Commits per day. Four blank days in twenty-nine, Christmas Day not among them.

| Project | Commits | Lines added | Lines removed |
| --- | ---: | ---: | ---: |
| world-edit-to-execute | 357 | 201 | 0 |
| neocities-modernization | 65 | 31 | 0 |
| translation-layer-wow-chat | 62 | 0 | 0 |
| delta-version | 38 | 25 | 0 |
| scripts | 32 | 4 | 0 |
| ao3-source-code-import | 22 | 0 | 0 |
| my-libs | 10 | 0 | 0 |

Columns are issue files written and completed. These exclude the founding commit, which imported issue files rather than writing them.

# What happened

## the tooling — 70 issues written, 29 completed

The issue-splitter and the repository meta-project, both built on days two and three.

| | |
| --- | --- |
| Started | day 2 |
| Guide symlinked into | 20 projects |
| Fallback lines deleted | 95 |

**The issue-splitter is the first real program in the repository.** It takes a large ticket and breaks it into sub-issues. Over 16 December it grows a queue, a producer, a streaming process that emits sub-issues as they are derived rather than at the end, a parallel processing loop, and flags to configure all of it — five sub-issues closed in order, in one day.

**The same day it gains a flag that pipes an issue file to an assistant on the command line and asks it to implement the steps described there**, with a dry-run mode that prints the prompt instead and a confirmation required unless explicitly overridden. Day two of the repository's existence.

Around it a terminal-interface library is assembled component by component — a core, checkboxes, a multi-state toggle, text inputs, menu navigation — then integrated back into the splitter so the same work can be driven by hand. Over the following day it gains numeric jump, repeated-digit selection for long menus, shift-digit to go back a tier, and inline-editable flag fields.

> **Thread — Fallbacks hide bugs** (starts here)
>
> A simpler non-graphical mode existed as a fallback for when the interface library was unavailable. **Ninety-five lines of it were deleted and replaced with an error naming what is missing**, and the commit states the reason: *fallbacks hide bugs — errors should be clear and intentional*. It is standing policy in the author's conventions rather than a discovery, and the later parts record where applying it caught something.

**On 17 December a program is written that reads a project's git log and produces a readable file presenting the development as a chronological story** — oldest commit first, *like reading a book*, full messages preserved, with filters for date range and completeness. It is the direct ancestor of the document you are reading, nine months earlier, as a shell script.

Also built: a viewer that gathers every project's vision document into one place, a project-detection tool for importing outside work into the collection, and on 4 January a maintainer's guide **symlinked into the documentation folder of all twenty projects**, so it is reachable from wherever you are standing.

One bug fixed here on 16 December comes back: **a counter written as a post-increment exits a script that aborts on failure**, because incrementing from zero returns the old value and the shell reads zero as failure. The identical bug is fixed again in the history reconstructor on 17 February, in a different script.

**Working transcripts — delta-version**

- [15 Dec](https://github.com/gabrilend/ai-stuff/blob/master/delta-version/llm-transcripts/dec-15-25.md) +6 agent
- [16 Dec](https://github.com/gabrilend/ai-stuff/blob/master/delta-version/llm-transcripts/dec-16-25.md)
- [17 Dec](https://github.com/gabrilend/ai-stuff/blob/master/delta-version/llm-transcripts/dec-17-25.md) +11 agent
- [18 Dec](https://github.com/gabrilend/ai-stuff/blob/master/delta-version/llm-transcripts/dec-18-25.md) +1 agent
- [21 Dec](https://github.com/gabrilend/ai-stuff/blob/master/delta-version/llm-transcripts/dec-21-25.md) +2 agent

## world-edit-to-execute — 357 issues written, 201 completed

Nine map file formats parsed, a runtime built on top of them, and a second architecture designed and archived in one day.

| | |
| --- | --- |
| Formats parsed | 9 |
| Tick rate | 62.5 Hz |
| Design archived | 2,700 lines |

The first three days are parsers, one format at a time: the archive container, the map information file, the trigger strings, the terrain, the units and buildings with their item drops and hero data, the doodads, the regions, the cameras, the sounds. Then a unified map structure they all feed, a tool that dumps a map's metadata, and an integration test.

**One parser needed a 1990s compression scheme implemented from scratch** — PKWARE DCL, used inside the archives — and its limitation was documented and cross-referenced two days before the implementation landed.

By the new year there is a game loop with a threading architecture, a death and resurrection system with corpses that decay and a ghost form for reviving heroes, and an attribute system mapping between two games' notions of a statistic. **The threading runs at 62.5 ticks per second — one every sixteen milliseconds — because that is the rate the original game used**, and a custom map's scripts are written against it.

#### 7 January · the pivot

A second architecture had been designed alongside the first: integrating with AzerothCore, an open-source World of Warcraft server, so the engine could host that game's content too. Five documents, about 2,700 lines — integration architecture, client architecture, data conversion pipeline, a bridge for custom abilities, and a phase reorganisation to fit it all in.

> All of it was archived on 7 January and the project returned to being a pure Warcraft III engine, on the stated reasoning that a game-engine reimplementation follows the legal precedent set by console emulators, and that attaching somebody else's live server to it is a different question with a different answer.

The 2,700 lines moved to a dated archive folder with a README explaining the context, and a postmortem was written beside the replacement design. The profession system built for the abandoned direction — gathering, crafting, recipes, cooldowns — was archived the same way rather than reverted.

> **Thread — Replaced designs are filed, not deleted** (starts here)
>
> This is the earliest instance. The city game does it with six tickets in September, each marked with what replaced it and why; the handheld operating system does it with twenty-two in July, moved to a superseded folder with a file mapping each old one to its replacement. **Nothing in the year is quietly removed.**

**Working transcripts — world-edit-to-execute**

- [7 Jan](https://github.com/gabrilend/ai-stuff/blob/master/world-edit-to-execute/llm-transcripts/jan-7-26.md) +296 agent

## neocities-modernization — 65 issues written, 31 completed



Sixty-five issue files and thirty-one completed, spread thin across the window rather than concentrated — a few commits most days from 17 December, with the heavier runs on 8 through 11 January. It is the project that gets attention in the gaps around whatever else is being built, which is the shape it keeps for the next nine months.

The window's last commit is titled, in full, *lost-and-found*, with no message body — a day's stray work swept up and named honestly rather than reconstructed into something tidier.

# What is open

| Project | State | Waiting on |
| --- | --- | --- |
| world-edit-to-execute | Archived | The integration with an outside game server is closed deliberately, with 2,700 lines of design preserved and a postmortem written. Listed because it is the decision the rest of the project is measured against. |
| world-edit-to-execute | Sketched | A matchmaking server split into nine sub-issues on 8 January, and a world editor phase created on the 2nd. Neither built. The project goes quiet after this window and does not return substantially until February. |
| the tooling | Specification | A commit history viewer was specified and not implemented. The narrative history generator was implemented. |

# Notes on the tree

One commit of 29,157 files established the layout every later part describes — a folder per project, each with its own issues, docs, notes, src and libs. Two things in it were later undone on purpose: the vendored libraries, removed in Part 3, and the practice of one commit touching forty projects at once, which the commit gates in Part 9 make difficult deliberately.
