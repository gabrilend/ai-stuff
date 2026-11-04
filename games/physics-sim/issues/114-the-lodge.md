# 114 - The Lodge: a cozy pachinko fan site at the front door

## Status: in-progress

## Depends on

- 115 (scene mode: the lodge's films are staged and recorded by the game)

## Sub-Issues

| ID   | Name                    | Dependencies | Description |
|------|-------------------------|--------------|-------------|
| 114a | picture-the-game        | None         | A script that runs the game unattended, photographs its window at chosen moments, and files each picture into `development-history/` with a notes file beside it |
| 114b | lodge-generator         | None         | The program that turns the hand-written rooms in `lodge/pages/` into pages in `docs/HTML/lodge/` |
| 114c | the-rooms               | 114a, 114b, 115 | The rooms themselves, written by hand |

Execution order: `114a` and `114b` in parallel → `115` → `114c`.

## Current Behavior

The lodge is built and follows the `lodge` skill. Five rooms in
`lodge/pages/`, each with its own stylesheet, build into `docs/HTML/lodge/`
(ignored by git) with `lodge/build`:

- **The Front Door** — what this machine is, in a few lines, with the crowd
  film (a row of balls from each side meeting), the room list, and the door
  to the house's README.
- **The Floor** — four films of the real machine, two by two on one screen:
  both balls breaking, one surviving while the other's pieces fly away from
  the hit, a gentle lean that costs nothing, and one ball's long way down.
- **The Drawing Table** — the board editor as a place where boards are
  drawn: colour is physics, the ready-made materials, and the six balls that
  exist only on paper.
- **The Parlour Wall** — pachinko itself: its history from the Corinthian
  bagatelle, where to see it, the collectors, its quieter relatives, and a
  place for neighbouring projects. Outside pictures and articles are links,
  never copies.
- **The Story So Far** — one screen: five days in March and an evening in
  October, with the long version linked.

The lodge gives no instructions, no download or build steps, and no issue
numbers. The films come from scene mode (issue 115) through
`scripts/film-a-scene`; they and every photograph are kept in
`development-history/`.

Still missing, so this issue stays open:

- **The workshop door.** The lodge is meant to link once to the project's
  source browser, which is also where the project is cloned from. Physics-sim
  has no source browser yet; the front door says the workshop is not open.
  How cloning works without HTTPS is undecided (see the documentation-site
  skill's *Not yet*).
- The two questions below, carried over from the first lodge.

## Intended Behavior

A **lodge**, as the `lodge` skill describes it: a small, cozy, hand-written
fan site about the thing this project is about, which is pachinko, where
someone who loves pachinko would enjoy an evening. Not a product page, a
manual, or documentation. Motion before words: one small film per mechanic,
staged in RAM by the real game. The story is a single screen. Links go
outward to real pachinko history, museums, collectors and relatives, and
once, plainly, to the project's source browser.

Layout inside the project:

```
lodge/
  pages/       the rooms: NNN-name.md (hand-written) and NNN-name.css
               (that room's own stylesheet, one per room)
  generator/   the program that builds the rooms, and its tests
  build        the run script
  output/      goodbye: the receipt the generator writes as its last act
docs/HTML/lodge/
               the built rooms (generated, never committed)
development-history/
               every picture and film of the game, numbered, with notes
```

## Suggested Implementation Steps

1. 114a and 114b as written in their files.
2. Scene mode (issue 115), then one film per mechanic with
   `scripts/film-a-scene`, each scene written in RAM.
3. 114c: the rooms, following the `lodge` skill.
4. When the source browser exists, add its door to the front door.

## Related Documents

- `/home/ritz/.claude/skills/lodge/SKILL.md` — the pattern.
- `/home/ritz/.claude/skills/documentation-site/SKILL.md` — the generator's
  rules (dead links stop the build) and rule 17, the source browser.

## Open Questions

- Three places in the game or its build print a warning and carry on: the
  built-in ramp stage when a board file will not load, four threads when the
  cores cannot be counted, and the latest raylib or cJSON when the pinned
  version is missing. The house rule treats a fallback as an error. Should
  these become errors?
- Several tickets no longer match the game (a parent left open after its
  parts closed, a duplicated 902b, headers from before the renumbering, stale
  numbers in the health ticket); the issue checker lists them. Should they be
  corrected in place, reopened, or left as the record of that week?
- (Answered by issue 115.) The game can now be driven by a scene file,
  ignores input while filming, and writes a goodbye receipt.
- (Answered.) The empty playfield at 45 seconds in the first unattended run
  was the view scrolled by input reaching the game's window.
