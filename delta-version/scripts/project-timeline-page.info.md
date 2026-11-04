# project-timeline-page.lua and project-timeline-page.html

## Overview

`project-timeline-page.html` is a template that knows how to draw the timeline
in a browser canvas, with the same palette and the same two modes per axis as
the PNG drawer. `project-timeline-page.lua` pastes the timeline JSON into it and
writes one self-contained page that opens from disk. Issue 067.

## The builder

| Option | Default |
|--------|---------|
| `--in=FILE` | `assets/project-timeline/timeline.json` |
| `--out=FILE` | `assets/project-timeline/project-timeline.html` |
| `--template=FILE` | `scripts/project-timeline-page.html` |
| `--dir=PATH` | hard-coded delta-version path |
| `--help` | |

The template must hold the data marker and the made-by marker exactly once
each; a template missing one, or holding it twice, is an error. `</` inside the
data is written as `<\/` so the data cannot end its own script element.

## The page's controls

| Control | Does |
|---------|------|
| X axis: birth order / birth date | the two `--x` modes (birth date needs sort by birth; otherwise it falls back to even spacing and says so in the picture's X label) |
| Y axis: days since birth / calendar | the two `--y` modes |
| commits / conversations / sweeps checkboxes | which sources light a day |
| colour pickers | each source, "both", the dark bar, the background |
| name filter, minimum lit days | which projects are drawn |
| sort | birth, name, most lit days, most recently worked on |
| pixels per day, column width, gap, calendar spacing | scale |
| project names | names under the columns on or off |
| save as PNG | downloads exactly what the canvas shows |
| load other timeline JSON | draws any file in the gatherer's shape |

Hovering a bar shows the project, its birth, its lit-day count, and the date
and sources under the pointer. A row of tiles above the chart counts projects
drawn and filtered out, days spanned, lit project-days, days lit by both, the
most-lit project, sweeps, and undated projects.
