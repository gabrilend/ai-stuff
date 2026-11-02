# 1001c — No line told twice

The third piece of 1001.

## Current Behavior

Built. Each chapter's first line is `## Chapter N: <turning> [thing]
(ledger lines A-B)` (`103-the-story.lua`'s `heading`); `told_so_far`
reads those headings back from the story file, and `tell(ledger_path,
story_path, case)` verifies the ledger (refusing a broken one), then
appends chapters only for the lines after the last one told, in one
append-mode write — an unchanged ledger adds nothing, and what is told is
never rewritten. `machine story <case>` (`107-the-story-commands.lua`,
docs/012) runs it on a case. Checked by
`tests/105-checking-no-line-twice.lua` and
`tests/108-checking-the-story-command.lua`.

Decisions: the story file's own headings are the record of what is told
(no separate bookmark file that could drift from it); the last chapter is
told even though more lines of its kind may follow — the next telling
starts a new chapter for them, so the story grows like the ledger rather
than holding its newest chapter back.

## Intended Behavior

A new chapter is only added for lines not yet told; the story grows like
the ledger — a second run over an unchanged ledger adds nothing.

## Suggested Implementation Steps

1. Each chapter's first line names the ledger line numbers it tells. 2.
   The incremental scan skipping already-told ranges. **Test:** every
   chapter's first line names ledger line numbers it tells; no line is
   told twice across two runs. Done (`heading`, `told_so_far`, `tell`).

## Blocked by

- 1001b
