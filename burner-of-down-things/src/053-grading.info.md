# 053-grading.lua

Where a request lands in the blueprint, and how deep it reaches.

| Name | In | Out |
|---|---|---|
| `grade(graph, touched, new_phases)` | graph (043); existing ids; phase digits of new issues | grade (`surface`, `middle`, `foundation`) and reach (sorted ids). Foundation when a touched issue is at `RULE.foundation_level` (0) or the reach is at least `RULE.foundation_fraction` (half) of the blueprint; middle when a touched issue has others built on it; else surface. New issues alone are surface |
| `locate(project, case, graph, request, options)` | | touched ids, new phases, the turn. Up to 3 locate turns, each told what was wrong with the last answer; raises an error after three, or on a breach |
| `parse_touched(text, graph)` | a locate answer | touched ids, new phases, findings |
| `record(case, request, grade, touched, new, reach, total)` | | appends `graded` (text `grade; touched …; [new …;] reach …`) and writes `output/<request>.grade` for the person |
| `parse_graded(text)` | a `graded` line's text | grade, touched, new, reach |
| `RULE`, `DEPTH` | | the grade lines (changes go to docs/balance-updates.md); depth numbers none 0 … foundation 3 |
