# Issue A10: The Pictures Join the Conversation

**Phase:** A - Infrastructure Tools
**Type:** Tool change (see-in-3d, the conversation exporter, transcript-site)
**Priority:** Medium
**Status:** Open
**Dependencies:** A08, A09 (see-in-3d); 020 (the exporter, `backup-conversations`); 035 (transcript-site)

---

## Why this exists

> also can we make it a requirement that it saves to the project, and is
> inserted into the llm-transcripts at the correct spot in computation?
> Specifically, for the HTML documentation version similar to this:
> https://abcd-games.net/site/story/index.html

When the agent looks at something from another side, that looking is part of
how the work was done. It should be kept with the project and shown in the
conversation exactly where it happened, so a reader of the story sees what
the agent saw when it decided what it decided.

## Current Behavior

Built and checked end to end on 2026-10-10 (a desk rendered from inside
delta-version appeared in this conversation's transcript between the words
before and after it, and on its story page):

- see-in-3d keeps every `render` and `imagine` in the project's
  `mind/imagination-portraits/<date-time>-<name>-<views|imagined>/` (her
  answer: "mind/imagination-portraits/"; every one, her answer too): the scene,
  JPEG copies, and `visual.info`. It prints `see-in-3d: kept PATH | CAPTION`.
  The project is the nearest folder at or above the working directory holding
  `llm-transcripts/`, or `--project=DIR`; with none, the render stops and says
  so. `--no-keep` is only for the tool's own regenerations (the gallery).
- The conversation parser (`libs/conversation-parser.lua`, which the exporter
  runs) reads those lines from the output of a command that runs see-in-3d's
  render or imagine — not from a search that merely quotes them — and writes
  `![caption](absolute path)` into the reply at that moment, the way commits
  are recorded. Chosen over editing `backup-conversations`, which had another
  session's uncommitted work: the parser is where the commit lines are made,
  and it had none pending.
- transcript-site copies each picture into the site's `pictures/` (at most
  720 pixels wide, the reading column), points the line at the copy, and
  stops the build naming any picture whose file is gone.

Tests: `scripts/test-see-in-3d.sh` (keeping, `--no-keep`, no project),
`scripts/tests/test_conversation-parser-pictures.lua`. Not yet: a
transcript-site test for the copying.

## Intended Behavior

1. **Kept in the project.** Every `render` and `imagine` also files what it
   made into the project it was run for, under
   `assets/visuals/<YYYY-MM-DD-HHMM>-<scene name>/`: the scene, the sheet, the
   imagined picture (JPEG copies for size), and `visual.info` — what made it,
   the session id (`CLAUDE_CODE_SESSION_ID`), and the moment (to the second).
   The project is the git project folder above the working directory, or
   `--project=DIR`. RAM stays the scratch space; the project keeps the result.
2. **At the right spot in the conversation.** The exporter already reads the
   session's full record, tool calls in order. Where it finds a see-in-3d
   call that filed a visual, it writes a picture line into the assistant's
   turn at that point, between the words before the call and the words after:
   `![front · right / top · angle](../assets/visuals/…/sheet.jpg)`, and the
   imagined picture the same way. The markdown stays readable on its own.
3. **Drawn on the story pages.** transcript-site's markdown renders those
   lines as pictures in the reading column, sized to it, captioned, and
   copies each into the site so the published pages carry their pictures.

## Suggested Implementation Steps

1. see-in-3d: `file_visual(project, kind, files)`, used by render and imagine;
   project found from the working directory or `--project`.
2. Exporter: recognise a see-in-3d tool call and its result in the session
   record; insert picture lines at that point. (The exporter has uncommitted
   work from another session: coordinate before editing it.)
3. transcript-site: images in its markdown; copy referenced pictures into the
   output; a test that a picture line becomes a captioned figure.
4. Tests: a render files into a fixture project with its info; a fixture
   session record with a see-in-3d call exports with the picture between the
   right two paragraphs.

## Answered Questions

- Home: `mind/imagination-portraits/`.
- Which: every render and imagining.
