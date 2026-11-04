# 604e — the box and the viewer

Part of 604. Depends on: 604c, 604d.

## Status: in-progress

## Current Behavior

Built: `./say` (makes the run folders in RAM and in `output/say/`, then
runs `src/042-say.lua`), and the viewer's `--watch=FILE` mode in
`delta-version/scripts/gif-viewer/main.lua`, now `viewer/main.lua` (the file's modification time
and size checked every quarter second; a change drops what was decoded and
loads it again; "waiting for the first picture" until the file appears).
`src/043-say-test.lua` runs the whole thing with stand-ins for `claude`
and the viewer: 14 checks passing. The viewer's own test now opens a
watched file too and passes (`test-gif-viewer.sh`, now `./test-gif-viewer`). Not yet proven: the
reload when the file changes (the test proves loading, not reloading),
and a run with a real Claude Code session.

`say` loads its code from beside itself and treats `DIR` only as where the
words, documents, tracker and output live, which is what lets the test run
it against a scratch project.

Before this there was no interactive front door, and the viewer did not
notice when a gif changed.

## Intended Behavior

- **`./say`** (root script) runs `src/042-say.lua`: a box drawn in the
  terminal to type into (finish with an empty line); then a status line per
  stage (words found, sessions running and finished, tracker updated,
  director drawing, wall rounds, rendered); then the viewer opens on the
  gif; then a chat log (`you:` / `studio:`) with a prompt at the bottom.
  `/done` keeps the result and closes the viewer.
- **The viewer's watch mode**: `view-gifs --watch FILE` shows one gif and
  reloads it whenever the file changes (checked by its modification time a
  few times a second).

## Suggested Implementation Steps

1. The terminal box and chat log (plain ANSI drawing; no curses).
2. The run folder in RAM, the stages in order, the viewer started in the
   background and stopped at the end.
3. The viewer's `--watch` mode, with its self-test extended.
4. An end-to-end check with the stand-in `claude`.
