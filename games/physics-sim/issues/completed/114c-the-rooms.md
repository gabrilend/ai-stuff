# 114c - The rooms

## Status: completed

## Parent Issue: 114 - The Lodge

## Depends on

- 114a (pictures to hang)
- 114b (a generator to build with)

## Current Behavior

Six rooms exist in `lodge/pages/`, 056 to 061, as in the table below, each
with its own stylesheet. The stylesheets are one design (dark floor, brass
rail, a lamp glow at the top) copied six times, differing only in the lamp
colour: brass (front door), green (machine room), orange (two boards),
yellow (workbench), ember (story), violet (back shelf). The rooms build into
`docs/HTML/lodge/` with 45 links, 16 backlinks and 3 pictures; two built
rooms were photographed in Firefox (pictures 011 and 012) and read
correctly.

How the rooms were written: every number and claim was checked against the
source, the git history (the subtree-merged history ending at commit
000bd1689), the tickets, the remediation report and the balance log. Where a
ticket's words disagree with the code (for example the health ticket still
says 100 health and 0.3 damage), the room follows the code and the back
shelf lists the disagreement. Quotations are verbatim, including the two
commits that carry no assistant's name and the owner's instruction for the
rooms, which is quoted in the story room:

> we should try and show off the most interesting parts, and not try to make
> ourselves look good by saying "we built 500 script files that do nothing
> important" or whatever.

No conversation from March survives, so the story room says so and is told
from the commits and tickets.

## Intended Behavior

The lodge for this project is **a pachinko parlour after closing time**:
the machines still lit, the floor quiet, someone who knows the place showing
a visitor around. Rooms, in reading order:

| Room | What is in it |
|------|---------------|
| The front door | What the game is, how to run it, the controls, the best picture, and the doors to every other room. This is the README. |
| The machine room | The thread pool and the double buffers: why the physics needs no locks, and the numbers the running game reports about itself. |
| The two boards | Player and adversary, mirrored; gates, health and damage, wrap zones; how a ball lives and dies. |
| The workbench | The standalone board editor and the board file format, where colour is physics. |
| The story so far | One long page: how the project was made, day by day, including the declared 100% and the remediation. |
| The back shelf | What is not done, what is stale, the ball types still on paper, and the open questions. |

Each room is written by hand, has its own stylesheet, and links to the
others and into `docs/` and `issues/`. Pictures come from
`development-history/`, linked where they live, not copied.

## Suggested Implementation Steps

1. Take pictures with 114a; fill in their notes.
2. Write each room and its stylesheet.
3. Build with 114b; open every room; follow the links; fix.
4. Picture one built room in a browser and file it with the rest.
