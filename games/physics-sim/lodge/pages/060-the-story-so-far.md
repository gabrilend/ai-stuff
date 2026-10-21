# The Story So Far

Pull up a chair by the stove. This is how the machine got built: five days in
March 2026, a quiet spring, a tidy-up in July, and a lodge in October.

## Where this story comes from

No conversation from the March build survives. The sessions it happened in
were pruned before anyone thought to save them, so this page is told from
what did survive:

- **the git history**: 223 commits between 16:06 on 16 March and 11:52 on 21
  March, adding 97,072 lines and removing 12,098 (source, documents and
  ticket files together; the downloaded libraries are not counted);
- **the tickets**: 182 completed issue files, each describing a piece of the
  machine, tracked phase by phase in progress files beginning with
  [phase 1's](../../issues/phase-1-progress.md);
- **the [remediation report](../../docs/sprint-remediation-report.md)**
  written on the 21st;
- **the ai-stuff progress report** that covers this window,
  [part 4, *167 of 167*](../../../../progress-reports/part-4-one-hundred-and-sixty-seven.md),
  which reads the same history from further away.

Nearly every commit carries the line *Co-Authored-By: Claude Opus 4.5*: the
code was written by an assistant, directed by the owner, one ticket at a
time. Two commits do not carry it. They are the owner's own words, and they
are quoted in full where they fall.

| Day | Commits | What the day was |
|-----|---------|------------------|
| 16 March | 82 | empty folder to a playable game, with an opponent, by ten at night |
| 17 March | 17 | mouse aiming, stages, and a board editor built *inside* the game |
| 18 March | 59 | the editor moved out into its own program; the physics argued with itself |
| 19 March | 56 | the tickets reorganised twice, four teams, "Project complete: 167/167" |
| 20 March | 0 | quiet |
| 21 March | 9 | the remediation: what four teams had broken between them |
| 24 March | 1 | the project moved off the repository's root into `games/physics-sim` |
| May | 0 | the libraries re-fetched and the game rebuilt; nothing committed |
| 22 July | 1 | the owner commits the spring's leftovers |
| 20–21 October | — | the lodge |

## 16 March: empty folder to a game

The first commit, at 16:06, is a plan and nothing else: the
[vision](../../notes/vision), the documents, and the tickets for a first
phase. Then the tickets fall one after another, about three minutes apart.
A build system at 16:14. The thread pool at 16:17. A window at 16:19. By
16:22 the first phase, four tickets, is closed.

The world comes next: the shape of the board, the pegs in their staggered
rows, the scoring zones, all drawn by 16:42. Then the balls: their state,
their physics, their collisions with pegs and walls, and dropping them with
a key, finished at 17:00. Then the part the whole project was for: a job
for every ball, a function that updates one ball on any thread, barriers
between passes, the parallel update wired into the main loop, and a
benchmark. That phase closes at **17:16, an hour and ten minutes after the
first commit**. The machine room described in
[the machine room](057-the-machine-room.md) is, in its bones, what stood at
quarter past five that afternoon.

Scoring, capturing balls, colour, particles and polish follow by 18:04, and
at that point every ticket written that morning is done.

What happens next is the most telling thing in the day. The commits stop
being the plan and start being the play:

- 18:12, *Fix ball scoring/disappearing bug*;
- 18:31, *Fix ball resurrection bug* (balls that had scored came back);
- 19:15, *Fix spawn blocking bypass via mouse movement* (you could stack
  balls inside each other by moving the mouse while dropping);
- 19:40, *Fix top wall boundary pushing spawned balls down*.

These are not bugs anyone finds by reading code. They are found by sitting
in front of the game, dropping balls, and watching. Between them come a
scrolling camera (18:25), a window that sizes itself to the monitor (18:47),
guard rails, an automatic-drop toggle, a drop point you can move, and a
buffer that holds the drop rate steady (19:12).

At 19:50 the phases are consolidated from nine to seven, the first of
several reshufflings. At 20:31: *Implement adversary system with dual boards
and cross-board physics*. The opponent arrives in one commit, the
mirrored board with it, and seven minutes later balls have health. The
evening is particles: ripples, splashes and fragments at 21:15, the
fragments made into pie slices of the ball at 21:23, and a **fountain**
twice: splash particles that kept spraying forever, fixed at 21:29 and fixed
again at 21:45, the second time traced to "stale task data", a job reading
last frame's leftovers. At 21:51 the particles move onto the thread pool. At
21:55 damage is changed to use how fast two balls close on each other rather
than how fast either is moving, so glancing blows stop being fatal. At 22:03,
the day's last commit, broken balls throw their pieces away from whichever
side hit hardest.

Eighty-two commits. The messages that day are titles, a line each; the
reasoning is in the tickets.

## 17 March: stages, and an editor inside the game

A late start and a short day. At 11:01 the mouse can steer, balls wrap from
the bottom of the machine to the top, and gentle hits stop doing damage. At
11:09 the stage system lands: buy a stage, the machine opens up and a new
board slides in.

The [balance log](../../docs/balance-updates.md) begins this day, and both
of its first entries are about the game feeling wrong rather than being
wrong. The drop rate falls from 5 balls a second to 1.7, because
"initial spawn rates were too fast, making the game feel rushed from the
start". And a damage threshold appears, because "even slow 50 px/sec
collisions dealt 5 damage, causing balls to die from insignificant contact."

From 17:48 to 18:37 a **board editor** is built into the game, a feature
every ten minutes or so: placing objects, removing them by dragging, lines
drawn in three clicks, saving with a notification, loading through a file
dialog, portals that teleport balls, colour sliders that change an object's
physics, and a pool of saved boards the game can draw new stages from. At
23:11 the editor becomes an overlay drawn over the running game. At 23:15
the tickets for taking it back out are written.

## 18 March: two programs

At one minute past midnight: *Implement standalone editor and remove editor
from game*. From here on, as [the workbench](059-the-workbench.md) tells it,
there are two programs sharing a file format.

The morning makes the board a file for good. At 08:40 the default board is
generated when the game is compiled. At 11:31 that is reversed for a reason
worth keeping: resizing the window **overwrote the board file**, so boards
became files the game requires and never writes. At 11:02 the two programs'
disagreement about board size is settled in the editor's favour, *Fix grid
dimensions - editor was correct (12x20, 50px)*. At 11:57 pegs and lines stop
being placed relative to the window and are anchored to the guard rails, so
resizing the window no longer changes the shape of the board.

Then a small argument the physics has with itself, all in ninety minutes. At
11:51 a **gravity assist** is fixed so that a ball rolling on a line is
nudged downhill instead of uphill. At 12:00 the assist is capped at 500
pixels a second, because a ball on a long slope was accelerating without
limit. At 13:21 velocity-dependent bounce arrives (issue 220): a slow hit
does not bounce at all, it slides, and with that the gravity assist and its
cap are both removed. Three commits to add a fix, limit the fix, and find
that a better rule made the fix unnecessary.

The afternoon is the editor growing up: drag-select and editing many
objects at once, colour sliders in tenths, an "in progress" flag for
unfinished boards, portal zones that fill their grid cell, vim keys in the
file picker. At 17:58 a new batch of tickets is written, including the ball
sleep system. At 18:08 ball health doubles and room for balls rises from 256
to 1024. At 19:24 the compile-time configuration system lands. At 19:25 the
first commit in the history without an assistant's name on it:

> uh this didn't get committed somehow. /shrug

A day of fifty-nine commits is a day where something gets missed, and that
line is the whole account of it. At 19:29 the grid grows to 14 by 22.

## 19 March: the tickets reorganised twice, then four teams

The day begins with tickets, not code. At 12:22 a ticket from the night
before is reopened (the grid had got denser but should have kept its size
in pixels). Then from 12:28 to 13:18, thirteen new issue files in under an
hour, each a single observation: board dimensions should be standardised,
the editor needs panels, a key to hide the interface, the window needs a
minimum width, drawers that fold away, the two scores should be kept apart, a material
picker, the opponent's board should not be tinted, gates should score more
than once, a ball-speed overlay, a bug where one kind of gate never scored
at all, a grid-based way to dispatch zones, and a key to pause the opponent.
It is the shape of someone playing and writing down what they see.

At 13:54 the whole ticket tree is reorganised: thirteen phases into ten,
about 150 files renamed. At 14:02 a second pass makes it nine. At 14:10 the
tracking itself is changed, and the commit spells out why:

> Philosophy change:
>
> Phases are team workstreams, not sequential release gates
>
> Issues can be worked on in any order based on dependencies
>
> Partial work enabled by tracking requirements within issues
>
> "up-to-date" replaces "complete" to indicate ongoing nature

Then **four teams** are assigned and run in parallel: A on infrastructure
(the self-editing config file, the spinning arms and track movers moved onto
the thread pool), B on physics (the slow-ball spatial hash, crushing), C on
track movers (choosing a path at a junction, back-and-forth motion, carrying
balls), D on the interface and editor (closed-shape detection and fill,
collapsible drawers, grid density sliders). Between 15:34 and 17:36 the
commits land from all four, sometimes a minute apart: sleeping balls, soft
collisions for piles, rotors, track movers, polygon collision, the zone
dispatcher, velocity statistics, wake conditions.

At 17:38:

> Project complete: 167/167 issues (100%)

It is written three and a half hours after the commit that said "up-to-date"
should replace "complete" because the work is ongoing. And it is not quite
true even on its own terms: at 23:40 that night a commit titled *Add
uncommitted implementations for issues 507, 839, 901f* adds the code for
three tickets that had already been counted in the hundred percent, among
them the pause key for the opponent and the material presets.

## 21 March: the remediation

Two days later the machine was looked at again, "after several sprints
without review" as the report puts it, and it was wrong in seven ways at
once. The [remediation report](../../docs/sprint-remediation-report.md),
committed at 10:05, lists them as they were seen: "strange textures all
over", player balls that do not spawn, invisible obstacles, obstacles in the
wrong places, lines everywhere, wrap zones that do not wrap, and particles
that only appear on the left side. Its finding:

> Investigation reveals coordinate system mismatches between polygon
> manager, board rendering, and zone calculations introduced during rapid
> Phase 9 development.

Underneath, it was one thing. **Several systems each worked out for
themselves where the board was.** The board renderer converted grid
positions to pixels with one formula; the closed-shape filler used another
that put things half a cell off; the opponent's board was flipped with a
formula that put row 0 one row past the edge; and the slot manager, which
was supposed to be the single source of truth for where everything sits, was
suspected of having drifted from how the others used it. Four teams had each been
correct against their own idea of where the board was, and nobody had been
given the board.

Seven sub-issues were opened with the report, and an eighth two minutes
later (issues 1001a through 1001h). All of them were worked the same morning:

- the coordinate systems unified, everyone converting grid to pixels through
  the one function (issue 1001b), with the shape filler's own fix folded in;
- the flip formula corrected to *rows minus one minus row* (issue 1001c);
- debugging overlays that had been left switched on by default switched off
  (issue 1001d), which was most of "lines everywhere";
- the wrap zones and their dispatch repaired (issue 1001e);
- particles positioned by the corrected gates (issue 1001f);
- resizing the window, which moved the board but not the balls on it, made
  to move both (issue 1001h).

And issue 1001a, the most alarming symptom on the list, *player balls don't
spawn*, closed itself with the most human resolution in the tracker:

> Player spawning works correctly. User must press SPACE to spawn balls or
> press A to enable auto-spawn. Initial report was due to forgetting to
> provide input during testing.

Two more fixes the same day: gates were drawn in one place and scored in
another (issue 1002), and the grid learned to have cells that are not square
(issue 1003). The day's last commit, at 11:52, folded the repairs back into
the tickets for the features they repaired, so that each ticket describes
the feature as it ended up rather than a feature plus a list of patches.

The progress report names the pattern this window teaches, and sees it again
in a different project the same week: **one owner holds the shared thing and
hands out slices.** Here the shared thing was a coordinate space; the fix
was to give it an owner after the fact.

## 24 March: moving out

Until now the whole project had lived at the top of the ai-stuff repository,
its tickets in the repository's own issue folder beside everything else. On
the 24th it was moved into `games/physics-sim` by a subtree merge, a move
that carries the full history with it, which is why every commit above can
still be read.

## Spring: rebuilt, not committed

In May the game was built again: the downloaded libraries in `libs/` and
the compiled game in `bin/` carry dates of 21 May, and the board file one of
11 May. Somewhere before July the dependency script also learned to fetch
and pin cJSON, the library that reads the board files, alongside raylib.
None of it was committed at the time.

## 22 July: the owner tidies up

The spring's leftover change, the improved dependency script, was committed
on 22 July, in the second commit in this history with no assistant's name
on it:

> clean up your stuff more. it was very difficult to clean up your room.
> don't worry it's all there, it's just a little disorganized.

## October: the lodge

On 20 and 21 October the project got this lodge: the rooms you are reading,
written by hand, a small program that builds them into pages, and a script
that runs the game with nobody at the keyboard and photographs it, filing
every picture in `development-history/` (issue 114). The game built in May
still ran: it opened, counted twelve cores, and started eleven workers. The
editor, which had not been built since, compiled without a warning.

The instruction for the rooms was the owner's: most projects in this
building do not run, so show what was really built and the most interesting
parts of it, and do not try to look good by counting things. In her words:

> we should try and show off the most interesting parts, and not try to make
> ourselves look good by saying "we built 500 script files that do nothing
> important" or whatever.

This one runs. What is still open is on [the back shelf](061-the-back-shelf.md).
