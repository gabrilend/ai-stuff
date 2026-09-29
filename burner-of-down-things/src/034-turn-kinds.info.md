# 034-turn-kinds.lua

The turn kinds table and turn folders (docs/005).

A **kind row**: `reads`, `writes` (arrays of path names resolved against the
case — `source`, folders ending in `/`, single files, `blueprint/issues/{{about}}-`
prefixes, `turn`, `request`), `crafts` (array of skill names), `template`
(prompt text with `{{slot}}` marks; first line `turn: <kind> <about>`).
Kinds: `outline`, `describe`, `build`, `repair`, `audit` and `inspect` (issue
507), `referee` (reads only the
blueprint, writes only `workflows/`, issue 506), `locate`, `amend`,
`storyteller` (issue 1001a — reads only the ledger and `input/`, writes
only `output/story/{{about}}.md`).

A **turn table**: `id` (`NNNN-kind-about`), `kind`, `about`, `folder`,
`case_folder` (strings); `reads`, `writes` (arrays of absolute paths; writes
are prefixes); `crafts`; `prompt` (string).

| Function | In | Out |
|---|---|---|
| `make_turn(case, kind, values)` | case table; kind name; slot values (always `about`) | a turn table; writes `prompt.md` and `confinement.lua` in `turns/NNNN-kind-about/` |
| `fill(template, values)` | text; table | filled text; refuses a slot with no value |
| `reads_source(kind)` | kind name | whether it may read the source — true only for `outline` and `describe` |

Slots per kind: outline — about, survey_summary, file_table, outline_path,
findings; describe — about, name, blocked_by, covered_files, issue_path,
outline_text, findings; build — about, target, issue_text, blocker_texts;
repair — those plus command, output; locate — about, request (file name),
request_text, issue_list, touched_path, findings; amend — about, request,
request_text, touched_texts, outline_text, findings.
