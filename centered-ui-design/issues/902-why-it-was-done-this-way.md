# 902 — Why it was done this way

**Phase:** 9 — Reading the machine
**Blocked by:** 901
**Blocks:** 904, 905
**Related documents:** delta-version issue 065

## Current Behavior

The reasons behind this project's choices live in three places that nothing
connects to the code: issue files (including `issues/completed/`), comments
at decision points in the source, and `llm-transcripts/`. The git history
holds the order things were built in.

## Intended Behavior

Each stop on the map gains:

- **alternatives**: list of (text string, source string) — other ways it
  could have been done and why they weren't, taken **only** from what was
  recorded, each with the file and line it came from. Nothing is invented.
  A stop with none says "no alternative was recorded here", which marks an
  undocumented decision.
- **chapter**: the commit and completed issue that introduced it, so the
  default path can be told as the development story, oldest first.

## Suggested Implementation Steps

1. For each stop, search issues, comments and transcripts for its name and
   nouns; keep passages that state an option and a reason.
2. Read `git log` oldest first; attach each stop to its first commit.
3. Report the count of stops with no recorded alternative.
4. Tests: fixture issue and transcript files with one known alternative.

## Lessons from the parallel build

delta-version issue 065b (completed): read issue files by paragraph, not by
line — wrapped prose cut at a line break reads as half a reason. Short or
shared names ("run", "main") must not tie a stop to every paragraph that uses
the ordinary word.
