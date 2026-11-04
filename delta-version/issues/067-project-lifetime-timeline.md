# Issue 067: Project Lifetime Timeline

**Status**: In progress — built and tested; open questions remain
**Priority**: Medium
**Created**: 2026-10-28
**Type**: New tool; a picture of the repository's working history
**Related**: `scripts/census-projects.lua` (the list of projects, reused);
completed issues 031 and 035 (imported and reconstructed project histories,
whose commit dates this reads); 036 (the commit history viewer, a text view of
the same history); `/home/ritz/programming/ai-stuff/scripts/libs/png-writer.lua`
(the PNG encoder)

---

## Why this exists

> can we make in delta-version a system that determines when the project was
> first created and then creates a timeline of when they were worked on? How
> it'd work is the X axis is time when each of them started, and the Y axis is
> a bar chart with mostly dark areas but some highlighted segments above that
> correspond to time when they were being worked on - both axes use time, but
> they use it differently. I want .png as output, with .HTML for creating
> custom visualizations like it.

## Current Behavior

Built and tested; open only for the questions at the bottom.
`scripts/project-timeline.sh` runs the gatherer, paints all four axis layouts,
and builds the page into `assets/project-timeline/`.
`scripts/test-project-timeline.sh` plants a three-project fixture repository
with known dates and checks birthdays, lit days, sweeps, nested-project
attribution, unparsed transcript names, all four pictures, and the page.

Found while building: the repository's own first commit (2025-12-15) touched
every project at once, and for about thirty projects it is their only commit.
Treating sweeps as "not work" first left those projects with no birthday at
all. Sweeps are now a third source: they set a birthday when nothing earlier
exists, and are drawn grey rather than lit. Sixteen projects are still undated:
folders that are not in git and have no transcripts.

## Intended Behavior

One column per project. Columns stand left to right in the order the projects
began, so the X axis reads "when was this born". Each column is a bar that
rises through time: its bottom is the project's first day, its top is today.
Most of the bar is dark. A day on which the project was worked on is lit, so a
project's column reads bottom to top as its life, with bright bands where
attention landed and dark stretches where it rested.

Both axes are time, used differently: X is a single moment per project (its
birth), Y is a span (every day since).

### Two placements per axis

| Axis | Mode | What a position means |
|------|------|-----------------------|
| X | `order` (default) | columns evenly spaced, sorted by first day; ties keep name order |
| X | `time` | a column's left edge sits at its first day on a calendar scale; columns born the same day stand side by side |
| Y | `age` (default) | every bar starts at the baseline; height = days since the project began, so older projects are taller and two bars at the same height are the same age |
| Y | `calendar` | the Y axis is the calendar; a bar starts at its birth date and ends at today, so the bars step up like a staircase and one horizontal line is one day across every project |

### Where "worked on" comes from

Three sources, kept apart in the data so a viewer can show any of them:

- **commits** — every commit that touches a file under the project's folder,
  by its author date, as a calendar day. Changes inside `llm-transcripts/` are
  not counted here (transcripts are the second source, and re-exports rewrite
  every project's transcripts at once).
- **transcripts** — each file in the project's `llm-transcripts/` is named for
  the day or days its conversation ran (`dec-15-25.md`,
  `aug-1-26-through-aug-4-26.md`, `dec-15-25_agent-1.md`). Every day a name
  covers is a day the project was talked about.

- **sweeps** — a commit that touches many projects at once (the first commit,
  gitignore unification, a repository-wide rename) is not work on each of
  them, but it does prove each existed that day. Commits touching more
  projects than a threshold (default 8) are recorded as sweep days, drawn grey,
  and counted apart; the count is printed every run so the threshold can be
  argued with.

A project's first day is the earliest day from any source. A project with
neither (a directory never committed and never talked about) has no first day
and is listed as undated in the data and on the terminal, not drawn.

### Three programs, kept apart

1. **The gatherer** reads the census list, one pass of `git log`, and each
   project's transcript folder, and writes the timeline data as JSON. It draws
   nothing.
2. **The PNG drawer** reads that JSON and paints the chart with its own small
   pixel font, through the shared PNG writer. It gathers nothing.
3. **The HTML builder** splices that JSON into a page whose controls rebuild
   the chart in the browser: both axis modes, either source, colours, scale,
   filters, sort, and saving the canvas as a PNG. A different JSON file can be
   loaded into the page, so the page draws any data in the same shape.

A runner script calls all three in turn.

## Suggested Implementation Steps

1. Gatherer `scripts/project-timeline-gather.lua`: project list from
   `census-projects.lua --json`; file-to-project attribution by longest
   matching project path (so `games/physics-sim/...` belongs to
   `games/physics-sim`, not `games`); transcript name parser for single days,
   `-through-` ranges and `_agent-N` suffixes, with unparseable names listed in
   the output rather than skipped quietly; sweep threshold option.
2. JSON shape (written with a `made_by` field naming the tool and command):
   `generated` (date), `today` (YYYY-MM-DD), `sweep_threshold` (integer),
   `sweeps` (integer), `projects` — a list of
   `{ name, first_day, commit_days[], transcript_days[], commits, transcripts }`,
   days as `YYYY-MM-DD` strings — and `undated[]`, `unparsed_transcripts[]`.
3. PNG drawer `scripts/project-timeline-png.lua`: `--x=order|time`,
   `--y=age|calendar`, `--source=both|commits|transcripts`, pixels per day,
   column width; a 3×5 pixel font for date ticks and rotated project names.
4. HTML template `scripts/project-timeline-page.html` and builder
   `scripts/project-timeline-page.lua`, writing a self-contained page (opens
   from disk; no server).
5. Runner `scripts/project-timeline.sh` with `--help`; outputs land in
   `assets/project-timeline/` with an `.info.md` naming what made each file.
6. Tests `scripts/test-project-timeline.sh`: transcript names, longest-path
   attribution, sweep counting, all four axis combinations produce a PNG
   ImageMagick can read with the expected size, the page contains the data.

## Open questions

- Should a sweep be allowed to set a birthday? Today it does, which puts about
  thirty projects' birth on 2025-12-15, the day the repository began, even
  though some are older. The alternative is to leave them undated, or to read
  a date from inside the project (its oldest file, its vision note).
- Is a commit's author date the right clock? Histories imported and rebuilt by
  issues 031 and 035 carry estimated dates; the picture inherits them.
- delta-version has no feedback inbox for HTML pages; the page has no feedback
  box. Should it get one, and where does the inbox live?
- Is a day the right grain for "worked on", or should a lit segment carry
  intensity (number of commits that day as brightness)?
- Should projects that only appear in transcripts (no commits yet) be drawn?
  Currently yes: a conversation is work.
