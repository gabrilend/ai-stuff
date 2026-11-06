# 103-the-story.lua

A case's ledger told back as chapters in plain words (docs/069, issue
1001): cut at the ledger's own turning points (1001b), each chapter's
heading naming the ledger lines it tells so no line is told twice (1001c),
and each line credited to whose it was (1001d). The machine's own telling,
from the ledger alone; a `storyteller` turn (034, 1001a) may retell it.

A **chapter**: `turning` (`opened`, `surveyed`, `described`, `refereed`,
`built`, `delivered`, `wider look`, `request`, `failure`, `repair`),
`thing` (what a request, failure or repair is about; `""` for a stretch of
one kind of work), `lines` (ledger lines, in order), `first`, `last` (their
`seq`). Working lines (`turn-started`, `turn-ended`, `goodbye`) join the
next chapter; a repair turn starting is itself a turning point.

A chapter on disk: `## Chapter N: <turning> [thing] (ledger lines A-B)`,
then `Whose: ...`, then one numbered sentence per ledger line.

| Function | In | Out |
|---|---|---|
| `chapters(lines)` | 016 `read()` lines, or a slice of them | `{chapters, waiting}`; `waiting` is the working lines at the end with no turning point after them yet |
| `turning_point(line)` | one ledger line | its turning point and thing, or nil for a working line |
| `whose(lines)` | a whole ledger's lines | `{[seq] = words}`: `the person`, `the machine`, or a role with the harness of the latest turn that plays it, e.g. `the builder (the stand-in)` |
| `heading(n, chapter)` / `chapter_text(n, chapter, whose)` | chapter number, chapter, `whose` | the chapter's first line / its whole text |
| `told_so_far(text)` | a story file's text (`""` for none) | the last ledger line told, and the chapter count |
| `path_for(record)` | case record | `<case folder>/output/story/<case>.md` |
| `tell(ledger_path, story_path, case_name)` | paths, case name | verifies the ledger (refuses a broken one), appends chapters for the lines after the last told; `{chapters, waiting, told_through}` |
| `TURNING`, `ROLES`, `TURN_ROLES` | | ledger kind → turning point; ledger kind → role (and the turn kinds that play it); turn kind → role |
