# shell-command-scan.lua

Reads a line of shell the way a shell splits it, so the refusal gates judge
commands instead of text. Used by `refuse-directory-change`,
`refuse-relative-commit-ref` and `refuse-foreign-lines`. Tested by
`tests/test_shell-command-scan.lua`.

## Data

**command** — one simple command a line would run.

| field | type | meaning |
| --- | --- | --- |
| `words` | list of strings | the command's words, quotes removed, redirect targets dropped, keywords in front (`if then do ! { time`…) dropped |
| `heredocs` | list of `{ body = string, delimiter = string }` | heredoc bodies, set aside from the words |
| `depth` | integer | 0 for the line itself, +1 for each nesting (substitution, eval, `bash -c`, shell heredoc) |

**invocation** — a git command split up by `git_invocation`.

| field | type | meaning |
| --- | --- | --- |
| `globals` | list of strings | git's own options before the subcommand, as typed (`-C`, path, `-c`, `x=y`, `-P`…) |
| `subcommand` | string | `commit`, `reset`, … |
| `args` | list of strings | everything after the subcommand |

## Functions

| function | takes | gives |
| --- | --- | --- |
| `commands(text [, depth])` | shell text | list of **command**, including the insides of `$( )`, backticks and `<( )` |
| `all_commands(text)` | shell text | `commands` plus the scripts carried by `eval`, `bash/sh -c`, and a heredoc fed to a shell, read recursively (depth limit 8) |
| `effective_words(command)` | a **command** | its words from the real command word on — `NAME=value`, `env`, `command`, `builtin`, `exec`, `time`, `nice`, `nohup`, `sudo`, `doas`, `timeout`, `stdbuf`, `xargs` stepped past; `nil` when nothing runs (`command -v`, assignments only) |
| `command_name(word)` | a word | the program it names (`/usr/bin/git` → `git`) |
| `git_invocation(words)` | effective words | an **invocation**, or `nil` if not git |
| `assignments(commands)` | list of **command** | `{ NAME = value }` for variables the line sets |
| `expand_known(word, values)` | word, assignments | the word with `$NAME` / `${NAME}` replaced where the line set them |

## Does not understand

Aliases, functions, `source`, `shopt -s autocd`, a script piped into a shell,
and variables set outside the line.
