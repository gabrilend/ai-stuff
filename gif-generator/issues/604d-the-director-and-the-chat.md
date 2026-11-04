# 604d — the director and the chat

Part of 604. Depends on: 604a. Blocks: 604e.

## Status: in-progress

## Current Behavior

Built as described below, in `src/040-director.lua` (wall rounds: 4), and
proven with a stand-in director (`src/041-director-test.lua`, 10 checks
passing: a misspelled first draft refused once and fixed, the gif placed
by rename, a chat turn re-rendering). **Not yet run with a real Claude
Code session.** The keeping of the result (prose, score, gif, chat log in
`output/say/<run>/`) lives in `042-say.lua` rather than here.

Before this, prose reached a score only through the porch's cluster,
which is not lit.

## Intended Behavior

`src/040-director.lua`:

- **first draft**: a headless session is given the prose, the score format,
  every word file's `meaning` and `example`, and one instruction: write the
  score to `tmp/shared-memory/say/<run>/score.lua`, then reply with one line
  saying what it drew. Its session id is kept.
- **the wall's teaching goes back**: the score is read and compiled; if the
  wall refuses it, every error is sent back to the same session
  (`--resume`), up to a bounded number of rounds; exhausted patience shows
  the errors and the last draft.
- **render**: a passing score is rendered by the ordinary pipeline to
  `tmp/shared-memory/say/<run>/now.gif`, which the viewer watches.
- **chat**: `message(text)` sends the person's words to the same session,
  which may change the score, word files or code, and must write the score
  again; then the wall and render run again. Its reply is returned for the
  chat log.
- **kept**: at the end, the prose, the final score, the final gif and the
  chat log are copied to `output/say/<run>/`.

## Suggested Implementation Steps

1. Prompt builder (reuses the porch's habit: the prompt is built from the
   format document and the word files, never written twice).
2. Session start and resume through the same launcher as 604c.
3. The wall loop and render.
4. `src/041-director-test.lua` with a stand-in that writes a score: a
   passing first draft renders; a bad draft gets the wall's text back and
   is fixed on the second round; a chat message re-renders.
