# project-timeline-gather.lua

## Overview

Works out when each project in the repository was born and which days it was
worked on, and writes that down as JSON. It draws nothing; the PNG drawer and
the HTML page read its output. Issue 067.

## Where the days come from

| Source | Read from | A day counts when |
|--------|-----------|-------------------|
| commit | one pass of `git log` over the whole repository | a commit changed a file under the project's folder (not inside `llm-transcripts/`) and touched at most `--sweep` projects |
| transcript | the names of files sitting directly in each project's `llm-transcripts/` | the name carries that date (`dec-15-25.md`, `dec-15-25_agent-1.md`), or a `-through-` range covers it |
| sweep | the same `git log` pass | a commit touched more than `--sweep` projects at once (the repository's first commit, a gitignore unification); it proves the project existed, it is not work on it |

A file belongs to the project whose path is the longest prefix of the file's
path, from the census's project list (`census-projects.lua --json`), so a nested
project (`games/physics-sim`) keeps its own files and its shelf (`games`) gets
none of them.

A project's **first day** is its earliest day from any of the three sources.
A project with none (never committed, never talked about) is **undated**:
listed, not drawn.

## Running it

| Command | Result |
|---------|--------|
| `project-timeline-gather.lua` | the JSON on standard output |
| `project-timeline-gather.lua --out=FILE` | the JSON to FILE, a summary on the terminal (counts, sweeps, undated projects) |
| `--dir=PATH` | read the repository above another delta-version folder (tests use a fixture) |
| `--sweep=N` | the sweep threshold, a whole number of projects (default 8) |
| `--today=YYYY-MM-DD` | the day every bar ends on (default the real today) |
| `--help` | usage |

Unknown arguments stop it with exit status 2; a failing `git` or census
command stops it with exit status 1.

## The JSON it writes

| Field | Type | Meaning |
|-------|------|---------|
| `made_by` | string | which tool wrote this, how, and why |
| `generated` | string, `YYYY-MM-DDTHH:MM:SS` | when it was written |
| `today` | string, `YYYY-MM-DD` | the day bars end on |
| `sweep_threshold` | integer | the `--sweep` value used |
| `commits_read` | integer | every commit in the history |
| `sweeps` | integer | how many of those were sweeps |
| `transcripts_read` | integer | transcript files whose names carried a date |
| `projects` | list of project records, in birth order (ties by name) | see below |
| `undated` | list of strings | project names with no day from any source |
| `unparsed_transcripts` | list of strings | transcript paths whose names carry no date |

Each project record:

| Field | Type | Meaning |
|-------|------|---------|
| `name` | string | path from the repository root (`alpha`, `games/beta`) |
| `first_day` | string, `YYYY-MM-DD` | earliest day from any source |
| `commits` | integer | commits that counted as work on it |
| `transcripts` | integer | transcript-days (a three-day range counts three) |
| `sweeps` | integer | sweep commits that touched it |
| `commit_days` | list of `YYYY-MM-DD` strings, sorted | days lit by commits |
| `transcript_days` | list of `YYYY-MM-DD` strings, sorted | days lit by conversations |
| `sweep_days` | list of `YYYY-MM-DD` strings, sorted | days it was only swept |
