# issue-transcript-references.info.md

Finds where each completed issue was discussed in a project's saved
conversations. Read-only: prints a report, changes nothing.

## How it is called

    issue-transcript-references [project-dir] [max-hits-per-issue]

- `project-dir` (string, path) — a project holding `issues/completed/` and
  `llm-transcripts/`. Defaults to delta-version.
- `max-hits-per-issue` (integer, default 12) — how many lines to print per
  issue for each strength of evidence.

Exit 0 with a report; exit 1 when either folder is missing or the transcript
folder holds no transcripts. A project with transcripts but no completed issues
exits 0 and says so.

## What the report holds

One section per completed issue, named by its filename stem, with up to two
lists of `llm-transcripts/<file>:<line>: <text>` entries:

| list | matched by | trust |
| --- | --- | --- |
| named | the whole filename stem, e.g. `014-create-maintenance-utilities` | high — nobody types that by accident |
| numbered | `issue 014`, `Issue 014`, `#014` without the stem | candidate only — a number can belong to another project's issue |

## What it relies on

- `libs/transcript-discovery.sh` decides what counts as a transcript (the
  `# Conversation Summary:` header line), so this never disagrees with the
  exporter about which files are conversations.
- Issues are searched concurrently; each writes its own slot file in a RAM
  directory under `/dev/shm/`, removed on exit, and the slots print in issue
  order.

## Why it does not edit the issue

Completed issues may be added to but not rewritten, and which hits deserve a
line in "related documents" is a reading judgement. The report is the input to
that judgement, not a substitute for it.
