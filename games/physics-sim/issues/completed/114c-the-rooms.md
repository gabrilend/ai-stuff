# 114c - The rooms

## Status: completed

## Parent Issue: 114 - The Lodge

## Depends on

- 114a (pictures to hang)
- 114b (a generator to build with)
- 115 (scene mode, for the films)

## Current Behavior

Five rooms exist in `lodge/pages/`, 056 to 060, as in the table below, each
with its own stylesheet: one design (dark floor, brass rail, a lamp glow at
the top) copied per room, differing in the lamp colour (brass, orange,
yellow, pink neon, ember). The floor's own stylesheet also hangs its films
two by two in a grid so the room fits one screen, which is what a room
having its own sheet is for. The rooms build with 25 links and 7 pictures.

How the rooms were written: every claim was checked against the source, the
git history, the tickets and the balance log; the outside links were looked
up and opened before being used. Quotations are verbatim: the owner's own
March commit message in the story room, and the plans for the split and
magnet balls on the drawing table.

The first version of the rooms (six of them: a front door with controls and
run commands, a machine room about the thread pool, the two boards, a
workbench, a long day-by-day story, and a back shelf of stale tickets) was
built and committed first, then replaced the same day when the owner set
the lodge pattern: a fan site, not a manual. Its words are in git history at
commit fa0244c21.

## Intended Behavior

The lodge for this project is **a pachinko parlour after closing time**,
written as a fan site about pachinko by someone who loves it. Rooms, in
reading order:

| Room | What is in it |
|------|---------------|
| The front door | A few lines about this strange two-board machine, the crowd film, the rooms, and the door to the house's README. |
| The floor | Four films of the real machine, each one mechanic, each with one sentence: both balls breaking, one surviving, a gentle lean, the long way down. |
| The drawing table | The board editor as a place boards are drawn: colour is physics, the ready-made materials, the balls on paper. |
| The parlour wall | Pachinko itself: history, where to see it, collectors, relatives, neighbouring projects. Links only. |
| The story so far | One screen: five days in March, an evening in October, the long version linked. |

No instructions, no download or build steps, no issue numbers, no counts
offered as achievements. Pictures and films come from
`development-history/`, linked where they live.

## Suggested Implementation Steps

1. Film each mechanic with `scripts/film-a-scene` (scenes written in RAM);
   fill in each film's notes.
2. Look up the outside links and open each before using it.
3. Write each room and its stylesheet.
4. Build; open every room; check it fits about one screen; fix.
5. Photograph the built rooms and file the photographs with the rest,
   including the ones that come out wrong.
