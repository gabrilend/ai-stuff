# 030-the-survey-summary.lua

The survey's viewing side: reads the two tables only.

| Name | In | Out |
|---|---|---|
| `compute(survey_folder)` | folder holding `files.tsv`, `links.tsv` | a summary table: `totals` {files, lines, bytes, links_inside, links_outside}; `by_language`, `by_role` (arrays of {name, files, lines}); `largest` (array of {path, lines}); `foundations` (array of {path, included_by}); `entry_points` (array of paths); `compile_units` (number); `outside` (array of {name, used_by}) |
| `text(summary)` | a summary table | text for a person |
| `write(survey_folder)` | folder | writes `summary.txt`; returns the text |
