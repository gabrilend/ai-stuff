# assets/project-timeline/

Everything in this folder is made by `delta-version/scripts/project-timeline.sh`
(issue 067), which runs three programs in a row. Re-run it to bring the files
up to date; do not edit them by hand.

| File | Made by | How | Why |
|------|---------|-----|-----|
| `timeline.json` | `project-timeline-gather.lua` | one pass of `git log` plus the dates in transcript file names, sorted into the census's projects | the single source both drawings read |
| `timeline-order-age.png` | `project-timeline-png.lua --x=order --y=age` | pixels painted straight into a PNG | columns in birth order, bars by age |
| `timeline-order-calendar.png` | `project-timeline-png.lua --x=order --y=calendar` | same | columns in birth order, bars on the calendar |
| `timeline-time-age.png` | `project-timeline-png.lua --x=time --y=age` | same | columns at their birth dates, bars by age |
| `timeline-time-calendar.png` | `project-timeline-png.lua --x=time --y=calendar` | same | columns at their birth dates, bars on the calendar |
| `project-timeline.html` | `project-timeline-page.lua` | the JSON pasted into `scripts/project-timeline-page.html` | the same chart, restyled and filtered by hand in a browser |

For current figures (projects dated, sweeps, undated projects), run the
gatherer with `--out=` and read its summary rather than trusting a number
written here.
