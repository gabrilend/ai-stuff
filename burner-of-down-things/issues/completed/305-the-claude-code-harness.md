# 305 — The Claude Code harness

The row that runs a real turn with Claude Code
([005](../docs/005-datapath-the-hands.md), *the harness table*).

## Current Behavior

Built as the `claude-code` row of `src/037-the-harness-table.lua`: `claude -p` with the prompt on standard input, instructions through `--append-system-prompt`, `--output-format json`, `--restricted`, `--tools Read,Write,Edit,Glob,Grep`, `--permission-mode acceptEdits`, `--permission-prompts none`, `--no-session-persistence`, a `--settings` deny rule for every read-only folder, and `--add-dir` for exactly the turn's folders. tests/040 checks the line for every kind (a build line never names the source). The live check, `tests/live/041-live-describe-turn.lua`, was run on 2026-09-27 with the owner's word, on the subscription: one real describe turn on a two-file program, kept (exit 0), about 21 seconds, exactly one file created — the issue, inside its allowed prefix — and nothing else changed. The owner, on money: "I don't have many API credits so I prefer using the subscription."

## Intended Behavior

The row's `start` builds this command, run from the turn's first writable
folder (a `cd` inside the harness's own shell line):

- `claude -p` with the prompt read from `prompt.md`;
- `--append-system-prompt` with `instructions.md`'s text;
- `--output-format json`;
- `--restricted` (file tools confined to the working folder and the added
  folders; command tools removed), `--tools Read,Write,Edit,Glob,Grep`;
- `--add-dir` for each other folder in the confinement's reads and writes;
- `--permission-mode acceptEdits` and `--permission-prompts none`, so edits
  inside the folders go through and anything else is refused, not asked;
- `--settings` with deny rules for writing into every read-only folder;
- `--no-session-persistence`.

Its `cost` is `subscription`. Its needs: `claude`. The JSON result's cost and
duration fields, when present, are copied into the `turn-ended` ledger line's
text.

| Decision | What each path leads to |
|---|---|
| The instructions are longer than one argument may be (128 KiB) | Refused, naming the size. Crafts are chosen per kind to stay well under it |
| `claude` exits non-zero | `failed`, with its stderr's last lines in the verdict |

## Suggested Implementation Steps

1. The command builder. **Test:** for each kind, the built line contains
   exactly the confinement's folders, and a build turn's line contains no
   source path.
2. A live check, run only by hand (`tests/live/`), never by the test runner:
   one describe turn on a two-file fixture source. It spends the owner's
   subscription and is started only when the owner says so.

## Blocked by

- 302
- 304
