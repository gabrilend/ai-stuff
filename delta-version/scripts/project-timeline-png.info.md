# project-timeline-png.lua

## Overview

Paints the timeline data (from `project-timeline-gather.lua`) as a PNG. One
column per project; each column is a dark bar from the project's first day to
today; each worked-on day is a lit band across the bar. Labels use a 3×5 pixel
font built into the file, and pixels go straight into a PNG through the shared
`scripts/libs/png-writer.lua`, so nothing else is needed. Issue 067.

## The two axes

| Option | Value | Layout |
|--------|-------|--------|
| `--x` | `order` (default) | columns evenly spaced, in birth order |
| `--x` | `time` | a column stands at its birth date (3 pixels per day); columns born the same day are pushed right to stand side by side |
| `--y` | `age` (default) | every bar rises from the baseline; height is days since birth; grid every 30 days |
| `--y` | `calendar` | the Y axis is the calendar; a bar starts at its birth date; grid at each month's first day |

## Colours

| Lit by | Colour |
|--------|--------|
| commit only | amber |
| conversation only | sky blue |
| commit and conversation on the same day | pale cream ("both") |
| sweep only | grey |
| nothing | the dark bar |

## Other options

| Option | Type | Default |
|--------|------|---------|
| `--in=FILE` | path | `assets/project-timeline/timeline.json` |
| `--out=FILE` | path | `assets/project-timeline/timeline-<x>-<y>.png` |
| `--sources=LIST` | comma list of `commit`, `transcript`, `sweep` | all three |
| `--day-pixels=N` | integer, pixels per day up Y | 2 |
| `--column=N` | integer, column width | 12 |
| `--gap=N` | integer, pixels between columns | 3 |
| `--dir=PATH` | the delta-version folder | hard-coded |
| `--help` | | |

An unknown option, source or mode stops it with exit status 2; missing or
empty data stops it with exit status 1. A character with no glyph in the pixel
font is an error naming the character, not a blank.

Prints the picture's size, the number of columns, lit days, and days lit by
both sources.
