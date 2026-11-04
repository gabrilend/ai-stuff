# 038-word-sessions — every unknown word taught at once

## Usable surface

- **brief(dir, run_dir, found) → path** — writes `<run_dir>/<word>.md`: the
  word, its sentence, the one-file rule, the check command, the two shipped
  examples, and the Patterns section of `docs/score-format.md`.
- **run_all(dir, run_dir, found_list) → jobs** — one headless session per
  word, all started together, all waited for. Each job: `word`, `sentence`,
  `brief`, `output` (the session's printed reply), `status` (exit code).
- **judge(dir, jobs) → jobs** — adds `ok` (boolean), `kind`, `problems`,
  using `034-words.check`. A word is taught only if its file passes.
- **update_tracker(dir, jobs, date) → path, reopened** — adds every taught
  word as one row of issue 605 in a single write; a tracker in
  `issues/completed/` is moved back with `git mv` and set to open first.
- **command(prompt, extra) → shell text** — the session command: `claude
  --print PROMPT --output-format json --permission-mode acceptEdits
  [extra] --allowedTools Read Write Edit Glob Grep 'Bash(luajit *)'`. The
  prompt comes before `--allowedTools`, which would swallow it. `claude` is
  replaced by `$SAY_CLAUDE` when set (tests only).
- **shell_quote, slurp, spit** — small helpers the director and `say` share.
