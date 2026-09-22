# progress-dashboard.lua

Counts a project's issues by phase and shows how many of each phase are done.
It is the statistics source that documentation and phase demos should point at
instead of writing numbers down.

## Commands

    progress-dashboard.lua [DIR]            terminal chart
    progress-dashboard.lua [DIR] -m         markdown table
    progress-dashboard.lua [DIR] -j         JSON (for demos and other tools)
    progress-dashboard.lua [DIR] -p PHASE   one phase only
    progress-dashboard.lua [DIR] -v         list every issue under its phase

DIR defaults to the scripts project. Exit status: 0 clean, 1 warnings printed,
2 bad arguments or no issues/ directory.

## How it decides

- **Done means moved.** An issue is done when it sits in `issues/completed/`
  (or `done/`). Checkboxes and "Status:" lines are counted for information only.
- **Retired issues** (in `superseded/`, `will-not-implement/`, `declined/`,
  `archive/`) are shown but left out of the progress percentage.
- **Phases come from names**, read by the shared reader `libs/issue-names.lua`:
  `522-x` is phase 5 issue 22, `1001-x` phase 10 issue 01, `9-007-x` phase 9
  issue 007, `A04-x` phase A issue 04. A file inside a `phase-N/` folder is
  counted in phase N. How many digits a compact name spends on the issue number
  is decided per project from evidence; see the reader's header comment.
- **Anything it cannot place is a warning**, printed after the chart (to stderr
  in terminal mode, as a section in markdown, as a list in JSON): a name with no
  valid phase, a folder it does not recognise, a phase with no progress file, a
  phase split that nothing confirmed, a name disagreeing with its folder.

## JSON shape

    { "generated": "<timestamp>",
      "issue_number_width": 2,
      "phases": { "<phase>": { "total", "completed", "open", "retired",
                               "unknown", "total_criteria", "ticked_criteria" } },
      "warnings": [ "<sentence>", ... ] }

All counts are integers; phase keys are strings ("1", "10", "A").

## Library use

    local dashboard = dofile("/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua")
    local phases, report = dashboard.collect("/path/to/project")
    local warnings = dashboard.warning_lines(report)
