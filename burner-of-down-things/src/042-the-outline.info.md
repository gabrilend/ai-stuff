# 042-the-outline.lua

Planning the whole blueprint in one turn, and checking the plan without a
model. An **outline row**: `id` (phase digit then two digits), `name`
(dashed lower-case words), `blocked_by` and `covers` (space-separated, `-`
for none) — all strings.

| Name | In | Out |
|---|---|---|
| `step(project, case, options)` | paths table; case table; pool options | the passing rows. Up to 3 outline turns; each failure appends `outline-failed` (about `attempt N`) and hands the findings to the next turn; success appends `outlined`. A breach or three failures raise an error |
| `check(rows, survey_rows)` | outline rows; `files.tsv` rows | array of `{ name, findings }` and whether all passed |
| `read(case)` | case table | rows, or nil and a finding (missing file, torn table, wrong header) |
| `words(field)` | a field | its words, `-` dropped |
| `CHECKS` | | `ids`, `names`, `blockers`, `cycles` (names the cycle in order), `coverage` (every code and build file covered; nothing covered that the survey lacks) |
