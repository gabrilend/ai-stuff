# The Back Shelf

The last room, past the stockroom door. Jars of things not used yet,
receipts that no longer add up, and a list pinned to the wall. Nothing on
this shelf stops the game from running; all of it is true.

## Plans still on paper

[The future ball types document](../../docs/008-future-ball-types.md)
describes six special balls, none of them built, in the order it suggests
building them:

| Ball | The idea |
|------|----------|
| Heavy | twice the gravity, less bounce, shoves other balls aside |
| Bouncy | almost no energy lost on a hit; stays in play and wanders |
| Sand | drops as ten tiny balls in a hexagon that scatter across many gates |
| Ghost | passes through the first three things it touches, then becomes solid |
| Split | splits in two at its first peg |
| Magnet | pulls nearby balls toward itself |

Two of its lines go further than the rest of the plan, and are worth reading
as written. Of the split ball: "when each smaller ball passes through a gate,
they reset to their original state, allowing for additional growth." Of the
magnet: "lowers the restitution of nearby balls, proportional to distance, to
help with clumping."

[The roadmap](../../docs/005-roadmap.md) lists, unscheduled: spatial
partitioning so a ball checks only the pegs near it, physics done four
numbers at a time, a pool of preallocated balls, a target of 500 balls at 60
frames a second, sound, networked play, touch screens, and sharing boards.

## Small things that are not finished

- A ball crushed between a spinning arm and a wall simply vanishes. The
  ticket for crushing (issue 901f) lists the particle effect for it as not
  done.
- In the editor, the "1:Peg" button overlaps the title, and the tools drawer
  on the left lists five tools where the toolbar has six; Track is missing
  from the drawer. Both are visible in the
  [first picture of the editor](../../development-history/010-editor-first-look-at-4s.png).
- The game cannot be driven without a person: it has no options to press a
  key, click, or take its own screenshot at a given second, and it does not
  leave a goodbye note when it exits. The pictures in this lodge are taken
  from outside its window, which is why a stray keypress could switch on
  automatic dropping during one of them.
- There is no automated test suite. The physics timing on screen, from the
  benchmark ticket (issue 111), is the closest thing.
- The [vision](../../notes/vision) asks for 60 frames a second with more
  than 100 balls. The game has room for it (see
  [the machine room](057-the-machine-room.md#what-the-running-game-says-about-itself)),
  but no picture has yet been taken with a hundred balls in play.

## Places the game quietly makes do

The house rule is that a fallback is a warning, and a warning is an error.
These three print a warning and carry on:

- If a board file cannot be loaded when a stage is bought, the game uses a
  built-in stage of two ramps.
- If the processor's cores cannot be counted, the thread pool assumes four.
- If the pinned version of raylib or cJSON cannot be found,
  `scripts/build-deps.sh` builds whatever the latest version is.

## Receipts that no longer add up

The tickets were renumbered twice on 19 March, and the bug fixes of the 21st
were folded back into the features they fixed. Some of the paperwork did not
follow:

- Ticket 221, the ball sleep system, is still open, with a table saying its
  five parts are waiting for work. All five (issues 221a to 221e) are
  complete; the parent was never closed.
- There are two tickets numbered 902b: an open one about a track drawing
  tool, and a completed one about the same tool.
- The completed health ticket (issue 606) is headed "Issue 809", its number
  before the renumbering, and describes health of 100 and damage of 0.3 per
  pixel a second. The game has used 200 and 0.15, with an 80 pixel-a-second
  threshold, since the [balance log](../../docs/balance-updates.md) changed
  them.
- The completed tickets for the board flip (issue 608) and the remediation
  (issue 1001) both still say "Status: Open", and the remediation's testing
  checklist is unticked, though every one of its sub-issues is complete.
- Four completed tickets name dependencies by numbers that no longer exist
  (issues 107, 305, 705 and 707).
- [The table of contents](../../docs/000-table-of-contents.md) lists twelve
  phases under their names from before the renumbering, and links progress
  files for phases 11 and 12 that no longer exist; the
  [roadmap](../../docs/005-roadmap.md) has nine.

The project's own issue checker finds these; run
`/home/ritz/programming/ai-stuff/scripts/validate-issues` on the project
folder to see the current list.

## Questions on the wall

- Should the game learn to be driven by a script (keys, clicks, and a
  screenshot at a given second, then a goodbye note), so that pictures and
  checks no longer depend on nobody touching the keyboard?
- Should the three fallbacks above become errors?
- When the receipts are put right, should the stale tickets be corrected in
  place, or reopened, or left as a record of how fast the week went?

Back to [the front door](056-the-front-door.md).
