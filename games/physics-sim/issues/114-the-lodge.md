# 114 - The Lodge: a hand-written front door for the project

## Status: in-progress

## Depends on

None. It reads what the other phases built; nothing it makes is read by the
game.

## Sub-Issues

| ID   | Name                    | Dependencies | Description |
|------|-------------------------|--------------|-------------|
| 114a | picture-the-game        | None         | A script that runs the game unattended, photographs its window at chosen moments, and files each picture into `development-history/` with a notes file beside it |
| 114b | lodge-generator         | None         | The program that turns the hand-written rooms in `lodge/pages/` into pages in `docs/HTML/lodge/` |
| 114c | the-rooms               | 114a, 114b   | The rooms themselves, written by hand, including the one-page story of how the project was made |

Execution order: `114a` and `114b` in parallel → `114c` (needs pictures to
hang and a generator to build with).

## Current Behavior

The lodge is built. Its three parts are complete (114a, 114b, 114c, in
`issues/completed/`): six hand-written rooms in `lodge/pages/`, each with its
own stylesheet; a generator and 17 passing tests in `lodge/generator/`; a
run script, `lodge/build`, that builds them into `docs/HTML/lodge/` (ignored
by git); and `scripts/picture-the-game`, which has filed twelve pictures
with notes into `development-history/`. Open `docs/HTML/lodge/index.html`
after running `lodge/build`.

Before the lodge, a reader arriving at the folder found no README and had to
open markdown files one at a time to learn that this is a working two-board
pachinko game; nothing the game draws had been saved as a picture; and the
story of how it was built existed only in git history and the `ai-stuff`
progress reports.

This issue stays open on its open questions, below.

## Intended Behavior

A **lodge**: a small set of connected, cozy pages that act as the project's
README. Each page is a **room**. The rooms are written by hand, in a voice
suited to this project, and show off the most interesting things the project
actually made or learned, honestly: what works, what was hard, what broke and
why, and what is still open. Nothing is padded; a count is shown only where
it says something.

Layout inside the project:

```
lodge/
  pages/       the rooms: NNN-name.md (hand-written) and NNN-name.css
               (that room's own stylesheet, one per room, duplicated even
               where two rooms look alike)
  generator/   the program that builds the rooms, and its tests
  build        the run script: makes sure the RAM scratch folders exist,
               runs the generator, prints its report
  output/      goodbye: the receipt the generator writes as its last act
docs/HTML/lodge/
               the built rooms (generated, never committed)
development-history/
               every picture of the game ever taken, numbered, each with a
               notes file
```

One room is **the story of the development process so far**: a single long
page, verbose and precise, using the whole page, built from the git history,
the issue files, the remediation report and the `ai-stuff` progress report
that covers this project. Things the owner emphasised are carried into it.

The rooms link to each other, to the project's documents and issues, and to
the `ai-stuff` README; the `ai-stuff` lodge will link back here.

## Suggested Implementation Steps

1. **114a — picture the game.** `scripts/picture-the-game`: start the game
   from the project folder (it reads `boards/` relative to where it runs),
   capture its window by title at each requested second, stop it, and file
   each capture as `development-history/NNN-name.png` with a
   `NNN-name.info.md` beside it holding the commit, the run options, a
   fingerprint of the sources, and empty "what it shows" and "story so far"
   sections for a person to fill. The game has no scripted-input options, so
   the pictures show what it does on its own (the adversary spawns
   unprompted).
2. **114b — the generator.** `lodge/generator/` in Lua, following the
   `documentation-site` skill:
   - collect every room and every link before writing anything;
   - Markdown subset: headings, paragraphs, lists, tables, fenced code, block
     quotes, rules, standalone images, inline code / bold / emphasis / links;
     any other line shape stops the build;
   - each room is written as `docs/HTML/lodge/NNN-name.html` with its own
     stylesheet copied beside it;
   - a link to another room becomes that room's page; a link with a section
     fragment lands on that section; a link to a project file becomes a
     relative path to the file; "issue NNN" in prose links to the issue file
     wherever it lives (open or completed);
   - backlinks: each section that other rooms point at ends with a "pointed
     at from" list, each entry returning to the exact paragraph;
   - any link to something missing (file, room, section, issue) fails the
     build, naming every one;
   - a contents rail on every room, the same on all of them;
   - the build prints what it counted, logs to `tmp/shared-memory/`, and
     writes `lodge/output/goodbye` last.
3. **Tests** for the generator: a fixture set of rooms covering a room-to-room
   link, a section link with its backlink, an issue mention, a dead link (the
   build must fail), and an unknown line shape (the build must fail).
4. **114c — the rooms.** Read the project, choose the space, write the rooms
   and their stylesheets, build, open, look, fix.
5. Add `docs/HTML/` to `.gitignore`.

## Related Documents

- `/home/ritz/.claude/skills/documentation-site/SKILL.md` — the patterns the
  generator follows (rule 16 is the hand-written voice).
- `docs/sprint-remediation-report.md`, `docs/005-roadmap.md`,
  `notes/vision` — sources for the story room.
- `/mnt/mtwo/programming/ai-stuff/progress-reports/part-4-one-hundred-and-sixty-seven.md`
  — the report covering this project's March build.

## Open Questions

- The game has no options to script its input or take its own screenshot
  (the house rule for graphical programs asks for `--key`, `--click` and
  `--screenshot`, and a goodbye receipt). Pictures are taken from outside the
  window for now. Should the game gain those options as its own issue?
- Three places in the game or its build print a warning and carry on: the
  built-in ramp stage when a board file will not load, four threads when the
  cores cannot be counted, and the latest raylib or cJSON when the pinned
  version is missing. The house rule treats a fallback as an error. Should
  these become errors?
- The back shelf room lists tickets whose words no longer match the game
  (a parent left open after its parts closed, a duplicated 902b, headers
  from before the renumbering, stale numbers in the health ticket). Should
  they be corrected in place, reopened, or left as the record of the week?
- (Answered.) In the first unattended run the picture at 45 seconds showed
  an empty playfield while the scores kept rising. The second run kept the
  board in view for a full minute: the view had been scrolled by input
  reaching the game's window, not a fault in the game.
