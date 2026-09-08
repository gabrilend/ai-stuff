# 167 of 167

*Part 4 · 13 – 25 March 2026*

A pachinko machine is built from an empty directory to a declared hundred percent in four days by four teams working in parallel. Two days later seven sub-issues open against coordinate-system mismatches the parallelism introduced.

| | |
| --- | --- |
| issues written | 394 |
| completed | 282 |
| projects | 3 |

## The window

The window runs 13 to 25 March. Sixteen days of silence before it, eleven after.

A pachinko machine — balls falling through a field of pegs into scoring zones, in C against raylib, with the ball updates spread across worker threads — is built at the repository root rather than in a folder of its own. It takes 351 of the window's 394 new issue files and 262 of the 282 completions.

**The commit messages from this period are changelogs**: a subject line and a list of what changed. By Part 6 they are prose explaining why a thing was done and what it cost. Where this part states a mechanism it is because the mechanism was written down; where it does not, the record does not have it.

**Commits per day.** 13: 3, 14: 0, 15: 0, 16: 82, 17: 17, 18: 71, 19: 56, 20: 0, 21: 9, 22: 0, 23: 10, 24: 1, 25: 1.

Commits per day. The 16th to the 19th carry 226 of the window's 250 commits, all on one project. The nine on the 21st are the repair.

| Project | Commits | Lines added | Lines removed |
| --- | ---: | ---: | ---: |
| the physics game (at the repository root) | 351 | 262 | 0 |
| neocities-modernization | 23 | 20 | 0 |
| ut2k4-symbeline-rumble | 19 | 0 | 0 |

Columns are issue files written and completed. The physics game had no folder of its own, so its issues sit directly in the repository's root `issues/` directory until the 24th.

# What happened

## the physics game — 351 issues written, 262 completed

Built at the repository root, declared complete on the fourth day, repaired on the sixth, and moved into its own directory on the seventh.

| | |
| --- | --- |
| Empty to playable | 1 day |
| Issues at 100% | 167 |
| Phases | 13 → 10 → 9 |
| Parallel teams | 4 |
| Sub-issues in the repair | 7 |

#### 16 March · eighty-two commits

Empty directory to playable game in one day. In order: a build system, a thread pool, a window, the world state, the peg grid, the scoring zones, ball state and physics, peg collision, boundary collision. Then the parallel pass — a task structure per ball, an update function running across threads, synchronization barriers between passes, a benchmark. Then scoring, ball capture, colour, particles.

Then past its own plan: a scrolling viewport with a camera, the window sizing itself to the monitor, guard rails, an auto-spawn toggle, a movable spawn point, and a buffering system to hold the spawn rate steady. Several arrive as bug fixes with their own tickets — **balls resurrecting after being scored, balls escaping the spawn block by moving the mouse, balls pushed downward by the top wall** — which is the shape of a day where the game is being played between commits.

#### 17–18 March · the editor arrives, then leaves

A board editor appears inside the game: place and remove objects, draw lines in a three-click workflow, save and load through a file dialog, edit an object's colour with sliders, teleport balls through portal zones, and an overlay mode putting the editor on top of the running game.

> On the 18th the editor is made standalone and removed from the game entirely, in one commit that closes a whole phase. Everything after it is two programs sharing a board format rather than one program with two modes.

The rest of the 18th is seventy-one commits at speed. A slot-based world layout. Velocity-dependent bounce, so a fast ball and a slow one do not rebound alike. Gravity assist along drawn lines, **capped at 500 pixels per second** once it was found to accelerate without limit. Lines and ramps unified into one abstraction. Drag-to-select with multi-object editing, vim keybindings in the file picker, Wayland clipboard support.

- **Pegs and lines were anchored to the window and became anchored to the guard rails.** Anchoring to the window means the board changes shape when somebody resizes it, which is a different game.
- **The editor and the game disagreed about the board's dimensions**, and the fix established that the editor had been right — twelve by twenty cells at fifty pixels — rather than splitting the difference.
- **A board must be a data file rather than generated at compile time**, after a resize was found to overwrite one.

#### 19 March · the work is reorganised twice before any code

Fifty-six commits, and the first fifteen are not code. Thirteen phases consolidated into ten functional groupings — core infrastructure, world and physics, feedback, display, gameplay, progression, competition, stages, editor, dynamic — with about a hundred and fifty ticket files renamed. Then, in a second pass the same day, ten became nine.

Dependencies moved from phase level to issue level and then down to individual requirements inside an issue, so partial work could be represented. The philosophy was written out.

> Phases are team workstreams, not sequential release gates. Issues can be worked on in any order based on dependencies. And *up-to-date* replaces *complete*, to indicate ongoing nature.

Then four teams were assigned in parallel — infrastructure, physics, track movers, interface — with eleven issues targeted for one sprint. They delivered: ball sleep states and the conditions that wake them, a spatial hash for nudging apart piled-up balls, rotors and track movers with their own physics, polygon collision, a panel interface for the editor, collapsible drawers, grid density sliders, and a configuration file that opens itself in your editor.

The day's last commit reads **Project complete: 167/167 issues (100%)**. It is written hours after the commit establishing that *complete* was the wrong word.

#### 21 March · the repair

> Investigation reveals coordinate system mismatches between polygon manager, board rendering, and zone calculations, introduced during rapid Phase 9 development.

Nine commits, opening with a diagnostic report and seven sub-issues: where the player spawns, unifying the coordinate systems, the formula that flips the board for the adversary, debug rendering, wrap zones, particles, polygon alignment. The repairs land the same day — zone dispatch and polygon positioning corrected on window resize, an architectural bug in how wrap zones were dispatched, a mismatch between where a gate was drawn and where it scored, and rectangular rather than square grid cells across every physics system.

> **Thread — One owner for the shared thing** (starts here)
>
> Four teams worked on things that all touch one coordinate space and no team owned it. **Each was locally correct against its own reading of where the board is**, and the composition was not. The same shape recurs five more times across the year: worker threads each loading their own copy of a cache, readers moved to a new storage tier while writers were not, a model choice reaching only some pipeline stages, an address duplicated across three driver files, two programs both naming the same files.

The bug fixes were folded back into the original feature tickets rather than left as a separate list, **so the record describes the feature as it ended up rather than the feature plus a patch.**

On the 24th the project moved off the repository root into `games/physics-sim` by a subtree merge preserving its history. It is still worked on: 182 completed tickets and 13 open now, against the 167 declared finished in March.

## neocities-modernization — 23 issues written, 20 completed

Site generation was consuming fourteen gigabytes and killing the machine.

| | |
| --- | --- |
| Peak memory before | 14 GB |
| After | ~3 GB |
| Throughput | 81 poems/sec |

- **The main thread was loading two large files it never used** — a 662-megabyte similarity matrix and a 77-megabyte vector file — while every generator function reads from pre-computed caches instead. The fix is to stop loading them and merely verify the caches exist.
- **Each worker thread was loading its own complete copy of 700 megabytes of cache.** With four threads that multiplies by four. The immediate fix was a retreat to a single thread.

**Then parallelism was recovered by changing who holds the data.** The main thread keeps the caches and hands out 80-kilobyte slices of work; workers request more when they finish rather than being assigned a batch up front. Memory settled at about three gigabytes with the default thread count restored, and a test at fifteen threads rendered 8,275 poems in 102 seconds.

> **Thread — One owner for the shared thing** (starts here)
>
> The same mistake as the coordinate space, made in memory rather than in meaning, in a different project in the same window. **Both fixes have the same shape: one owner holds the shared thing and hands out slices.** The poetry site reached it in two days; the game reached it by unifying its coordinate systems after the fact.

The parallel file-writing layer was also rebuilt as a C thread pool called through the foreign-function interface, replacing a library whose shared-table access had been unstable. Generation stays sequential — it is fast enough — and only the writing to disk is spread out.

## ut2k4-symbeline-rumble — 19 issues written, 0 completed

Three commits on the 13th, all planning, spending the whole budget on one problem.

The problem is hiding parts of an Unreal Tournament 2004 level that a player should not be able to see, at runtime. A 750-line technical document covers the geometry types, how to detect what occludes what, strategies for modifying the rendering, performance, and multiplayer.

Seven tickets come out of it and **one is marked critical before any work starts**: the engine stores level geometry in a binary space partition tree that the mod cannot manipulate the way it manipulates placed objects. Making a placed object transparent is a property change; making a wall transparent is not. The critical ticket is research to find out whether it can be done at all — named as a risk in the plan rather than discovered halfway through it.

# What is open

| Project | State | Waiting on |
| --- | --- | --- |
| the physics game | Worked around | A hundred percent was declared on the 19th and seven sub-issues opened on the 21st against coordinate-system mismatches from the parallel sprint. The immediate repairs landed the same day. **Whether four parallel teams can share a coordinate space without one owning it was not answered, only worked around.** |
| the physics game | Still going | The 167 tickets declared complete have since become 182 completed and 13 open — which is what the ticket system's own *up-to-date rather than complete* wording predicted, hours before the milestone contradicted it. |
| ut2k4-symbeline-rumble | Critical unknown | Whether the engine's level geometry can be made selectively invisible at runtime at all. The project goes quiet after these three commits and does not return until June. |
| neocities-modernization | Recovered | Parallel page generation works again, but the word-page generator was still to be parallelised and a ticket was opened rather than done. |

# Notes on the tree

**No working transcripts survive from this window.** Every later part links the conversations behind each project; these months are inside the hundred and eighty sessions the pruner deleted, so there is nothing to link to. The record here is commits and issue files only.

This is the window where a project was built at the repository root — its issues, source, documents and boards sitting beside every other project's folder — and moved into its own directory on the 24th by a subtree merge that preserved its history.

One commit in the middle of the 18th reads, in full, *uh this didn't get committed somehow. /shrug*. A day of eighty commits is a day where something gets missed, and saying so is cheaper than a reconstruction.
