# The First Fourteen Weeks

*Part 1 · 3 September – 14 December 2025 · from file timestamps*

The project begins on a Wednesday afternoon with eight Lua files and a design document written after them. Fourteen weeks later it holds twenty-four projects and has outgrown being remembered, and everything goes into version control.

| | |
| --- | --- |
| projects | 24 |
| files written | 1,023 |
| weeks | 14 |

## The window

The window runs 3 September to 14 December 2025. It is the only part with no commits behind it: everything here is measured from when files were last written, because version control arrives on the last day.

**Why the window starts on 3 September 2025.** The founding commit imported files that already existed, and their timestamps reach much further back — to a notes folder from 2021 and, through vendored libraries, to a Lua distribution from 2001. **None of that is this project.** The earliest file belonging to the work these reports describe was written at 25 minutes past two on the afternoon of Wednesday 3 September 2025.

**Why it ends on 14 December.** The next day, all of it goes into git in one commit of 29,157 files, and the record stops being inference. That commit and the four weeks after it are *29,157 Files*.

**How the 1,023 files were arrived at.** Of the founding commit's 29,157 files, 28,905 are still on disk. Dropping vendored libraries, two large imported trees — a console toolchain and a game's source — and everything outside plausibly authored places leaves 2,081. Restricting those to the window leaves **1,023 files across 24 projects**, which is what the charts below describe.

**Commits per day.** Sep 1: 15, 8: 36, 15: 42, 22: 218, 29: 8, Oct 6: 3, 13: 5, 20: 175, 27: 143, Nov 3: 34, 10: 106, 17: 38, 24: 0, Dec 1: 79, 8: 121.

One column per week, labelled by the Monday it starts. The height is how many surviving authored files were **last written** that week. Four spikes and one silent week — 24 to 30 November, which produced nothing that survives.

| Project | Commits | Lines added | Lines removed |
| --- | ---: | ---: | ---: |
| issue files (tickets and blueprints) | 0 | 331 | 0 |
| source | 0 | 218 | 0 |
| documents | 0 | 120 | 0 |
| inputs (notes, images, archives) | 0 | 59 | 0 |
| notes | 0 | 48 | 0 |
| scripts | 0 | 33 | 0 |

The *added* column is a file count and the *commits* column is zero throughout, because there are no commits in this window — the shared table is being borrowed for a job it was not designed for, which is noted rather than disguised. The remainder of the 1,023 sit at a project's root rather than in any of these folders.

> **Thread — Blueprints outnumber code** (starts here)
>
> **331 issue files against 218 source files**, in the first fourteen weeks, before anybody wrote that rule down. The collection writes what it intends to build in more detail, and more often, than it builds it. Every later part shows the consequence — a project with 94 tickets and no code, a window writing 171 blueprints and finishing 12 — and it is already true here, before git.

# What the timestamps show

## the fourteen weeks — 24 projects, 1,023 files

One afternoon in September to the night before version control, with each project drawn from the first day one of its files was written to the last.

| | |
| --- | --- |
| Days | 103 |
| Working weeks | 14 of 15 |
| Projects | 24 |
| Files | 1,023 |
| Busiest week | 218 22–28 Sep |

#### Wednesday 3 September · the first afternoon

The earliest surviving file is `combat.lua`, written at 14:25. Seven more follow it before the evening — a monster, an item, a main entry point, a maze, a hero, a unit — and at 16:32, between the maze and the unit, a plain-text game design document.

> The design document is not the first file. It is the seventh, written two hours into the work, after most of the code it describes.

The project it belongs to is a contest entry, and it is eight files that were never touched again. Nothing in the collection predates that afternoon.

#### Thursday 4 September · the method arrives

At 08:50 the next morning, in a different project — the one that lays poetry out as a printable book — a file called `CLAUDE.md` is written. **It is the earliest one anywhere in the collection.** That is the file an assistant reads before doing anything: the conventions, the preferred language, how issues are to be written, what a fallback is and why there should not be one.

**So the working method is one day younger than the work.** The day after the first code, somebody wrote down how the work was to be done. Two more copies of it appear the same afternoon, in nested backup folders, which is the shape of somebody keeping a spare before they trust the arrangement.

> **Thread — Fallbacks hide bugs** (first seen in Part 2)
>
> The conventions file written on day two is where the rule lives: prefer an error to a fallback, and notify every time one is used. **The method is one day younger than the work.** Part 2 is where it first costs ninety-five deleted lines to apply, and four later parts record what applying it caught.

The next day a notes file appears in two projects at the same second — the first trace of a shared notes vault being synced into more than one place. That vault is the thing whose files reach back to 2021, and it is the only part of the collection genuinely older than this window.

#### The shape of fourteen weeks

| Project | First | Last | Files |
| --- | --- | --- | ---: |
| cloudtop-contest | 2025-09 | 2025-09 | 8 |
| words-pdf | 2025-09 | 2025-12 | 106 |
| neocities-modernization | 2025-09 | 2025-12 | 158 |
| magic-rumble | 2025-09 | 2025-09 | 21 |
| factory-war | 2025-09 | 2025-09 | 1 |
| adventure-hero-quest | 2025-09 | 2025-09 | 10 |
| links-awakening | 2025-09 | 2025-09 | 2 |
| console-demakes | 2025-09 | 2025-09 | 24 |
| handheld-office | 2025-09 | 2025-11 | 179 |
| games/galactic-battlegrounds | 2025-09 | 2025-09 | 1 |
| scripts | 2025-10 | 2025-12 | 8 |
| RPG-autobattler | 2025-10 | 2025-10 | 143 |
| healer-td | 2025-10 | 2025-10 | 21 |
| progress-ii | 2025-10 | 2025-12 | 101 |
| continual-co-operation | 2025-11 | 2025-11 | 19 |
| risc-v-university | 2025-11 | 2025-11 | 28 |
| ai-playground | 2025-11 | 2025-11 | 42 |
| resume-generation | 2025-11 | 2025-11 | 3 |
| games/gameboy-color-rpg | 2025-11 | 2025-11 | 20 |
| dark-volcano | 2025-11 | 2025-12 | 39 |
| adroit | 2025-12 | 2025-12 | 50 |
| delta-version | 2025-12 | 2025-12 | 37 |

Each bar runs from the first day one of a project's files was written in this window to the last. Bars are placed by month, so a project confined to a few days shows as a single block. A bar is not a claim that work happened across all of it — only that something was written at each end.

- **Ten projects appear in September alone**, most of them lasting days. A contest entry, a card game, a factory game, an adventure game, a Zelda project, a console-demake toolchain — several are a single file each. **This is a month of starting things**, and the ones that last are not obviously the ones that got the most attention that month.
- **The largest single project in the window is a text editor for a handheld games console** — a Game Boy Advance-styled editor with hierarchical input and networked assistance — at 179 files across September to November. It is not one of the projects the later reports follow, which is worth stating plainly: **the biggest thing here went quiet.**
- **Two projects run the whole window and keep running for another nine months**: the poetry website at 158 files and the poetry book at 106. They are the two that read the shared notes vault, and they appear in every report in this series.
- **October and November are bursts, not a stream.** Three weeks in October produce eight, three and five files; the week of the 20th produces 175. An auto-battler contributes 143 of them in a single day, 22 October. A tower-defence game contributes 21 on the same day.
- **One week produced nothing that survives** — 24 to 30 November. It is the only silent week in the window, and it sits directly before the run that ends in version control.

#### 7 December, 22:53 · the repository is decided on

Eight ticket files are written in seven minutes on a Sunday night, in a project that did not exist that morning. Their names are the argument: comprehensive git repository setup, discover and analyse gitignore files, design a unification strategy, implement pattern processing, a project discovery system, a ticket distribution engine.

> The tool for managing a collection of projects was specified eight days before the collection entered version control, in one sitting, late at night.

It is the clearest thing the timestamps say. **Nothing forces a repository until the number of things exceeds what one person can hold**, and this window puts that threshold in the first week of December 2025, after fourteen weeks and twenty-four projects.

#### 14 December, 23:20 · the last night

The final two files written before the founding commit belong to the poetry website: a document weighing two ways of running work in parallel against each other, and a ticket to build graphics-card compute infrastructure. **The last thing done before the record begins is a decision about how to make something faster** — and the graphics-card path it proposes is not actually built until March, in *167 of 167*, three months and a whole repository later.

## what this cannot tell you — four caveats

Everything above is inferred from when files were last written. Four things that does not record, each bending the picture in a known direction.

> A modification time is not a record of work. It is a record of the last time a file was written — and only for the files that still exist.

- **It only counts survivors.** A file written in September and deleted in October leaves nothing at all. Every count here is a floor, and the earlier weeks are floored harder than the later ones.
- **It records the last touch, not the first.** A document started in September and revised in December appears only in December. So the early weeks are undercounted by exactly the amount of work that was later returned to — which is to say, by the work that mattered most.
- **Any bulk operation overwrites it.** A copy, a restore or a sync stamps its own moment onto everything it touches, which would turn one afternoon of copying into a fake week of work. The test for it is to count distinct timestamps against total files per month: a bulk copy gives thousands of files the same second, editing gives each its own. **Inside this window the four months score 0.76, 0.83, 0.83 and 0.73** — roughly three files in four written at their own moment. Two months elsewhere in the collection score 0.23 and 0.25 and are excluded, which is part of why this window starts where it does.
- **It says nothing about what was done.** This page can say that 143 files appeared in an auto-battler on 22 October. It cannot say what any of them contained, whether the day went well, or what was decided. Every other page in this directory can, because somebody wrote it down.

**And unlike every other page here, this one cannot be regenerated.** It is built from live filesystem state rather than history. A single checkout, restore or sync would rewrite the evidence and make this page wrong without changing one commit.

# What is open

| Project | State | Waiting on |
| --- | --- | --- |
| the fourteen weeks | Unrecorded | **No conversations, commit messages or progress notes exist from this period.** What any of these twenty-four projects was for, what was decided, what was abandoned and why — none of it is written anywhere the repository can reach. The files are the only witnesses and they say when rather than what. |
| handheld-office | Went quiet | 179 files across three months, the largest project in the window, and it does not appear in any later report. Whether it was finished, abandoned or merely paused is not answerable from here. |
| the notes vault | Outside | The shared notes synced into several projects are older than this window and live outside the repository. Their real history is on another disk and would answer more than anything measurable here. |
| the silent week | Ambiguous | 24 to 30 November produced nothing that survives. Whether that was a week off or a week whose output was deleted **cannot be settled by this method**. |

# Notes on the tree

Everything on this page was measured by listing the founding commit's file tree, keeping the paths that still exist on disk, reading their modification times, and filtering as the introduction describes. It reads the working tree and the git index and changes neither.

The filtering is worth re-running rather than trusting, and so is the check that separates editing from copying: for each month, count distinct timestamps against total files. Inside this window every month passes. Two months elsewhere in the collection — October 2021 and May 2024 — fail it badly, which is part of why this window starts where it does.
