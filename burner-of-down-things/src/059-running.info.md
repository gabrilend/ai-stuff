# 059-running.lua

Does whatever a case is waiting for, from the ledger alone.

| Name | In | Out |
|---|---|---|
| `waiting_steps(case)` | case | array of step names in order: `survey` (no `surveyed`), `describe` (not outlined, or a row neither described nor describe-failed), `build` (an issue neither built nor build-failed, or never delivered — but not while an issue stays build-failed), `update` (a request waiting that is not held for the person) |
| `run(project, case, say)` | paths table; case; a print function | array of `{ step, sentence, ok }`; stops at the first step that cannot finish; writes the center's view at the end |
| `STEPS` | | step name → function(project, case, say) → sentence, ok |
