# 040-director — prose to a score, then a conversation

## Usable surface

- **start(dir, run_dir, prose, say) → state** — writes
  `<run_dir>/director-brief.md` (the prose, every word file's meaning and
  example, the whole score format) and starts a session on it, which writes
  `<run_dir>/score.lua`. Then the wall: a refusal is sent back to the same
  session, up to 4 rounds. A passing score is rendered to
  `<run_dir>/now.gif` (by way of `now.gif.partial` and a rename). `state`:
  `session_id`, `reply` (its words), `facts` (render facts, or nil),
  `refusal` (the last refusal, when it never passed). `say(line)` receives
  each status line.
- **message(dir, run_dir, state, text, say) → reply, facts, refusal** — one
  chat turn on the same session (`--resume`); it may change the score, the
  word files or the studio's code, and writes the score again.
- **read_and_compile(dir, run_dir) → compiled | nil, refusal** — word files
  reloaded each time, since the director may change them.
- **render(run_dir, compiled) → facts**.
- **brief(dir, run_dir, prose, vocabulary) → path**.

The session's JSON reply is read with dkjson from the shared shelf
(`/home/ritz/programming/ai-stuff/libs/lua/`).
