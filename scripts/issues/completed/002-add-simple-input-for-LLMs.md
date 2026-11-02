# Issue 002: A File of Just the Requests

The request, as first written:

> the LLM-transcript functionality should also generate an additional
> file which stores just the user submitted prompts, one per line. Then,
> when the LLM is restoring it's old context, it'll have the capability of
> seeing exactly what the user requested, and examining their old responses
> for clarification if they ever request a specific modification that seems
> out of place or undefined. This file should be stored alongside the
> transcript files.

## Current Behavior

The exporter writes one transcript per conversation into
`llm-transcripts/`. A model restoring its context has to read whole
transcripts, answers and all, to find out what was asked.

## Intended Behavior

Beside every transcript, a file with only the person's requests, one per
line, so the requests can be read at a glance and the transcript opened at
the one that needs explaining.

## Suggested Implementation Steps

1. A tool that reads a transcript and writes its requests, one per line.
2. The exporter runs it on every transcript it writes, and removes the file
   when the transcript is renamed or retired.
3. The commit route carries the file the way it carries transcripts.
4. A way to fill in transcripts the exporter will never write again.

## Decisions

- **Built from the patched transcript, never from the session log.** The
  developer's decision: the prompts file follows the patches, so a
  redaction always applies to it. Exact wording is lost only where a patch
  redacted it, and the prompts file marks that spot the same way the
  transcript does. The cost is that the text is the transcript's rendering
  (wrapped at eighty columns, pasted-back lines marked `> `), not the
  keystrokes.
- **Where:** `llm-transcripts/prompts/<transcript name>.txt`. "Alongside"
  without being *in* the folder: every scanner of transcripts reads
  `llm-transcripts/*.md` one level deep, so a sub-folder can never be
  mistaken for a transcript, and the same name makes it findable.
- **One line per request:** line breaks as `\n`, backslashes as `\\`,
  carriage returns as `\r`. Reversible, and line N is request N, so no
  prefix or number is needed.
- **Helpers are skipped:** a helper's requests were written by the model that
  spawned it, not by the person.
- **The exporter writes it on the unchanged path too,** so a missing file
  comes back on the next export; a file that would not change is not
  rewritten.
- **A failure fails the export** (house rule: failures are reported), but
  only after the transcript itself is in place.
- **Not in the corpus backup:** `backup-transcript-corpus` copies `*.md`;
  a prompts file is derived from a transcript and can always be remade.

## What Happened

Built on branch `claude/user-prompts-file`.

- `transcript-prompts` (new, LuaJIT) reads a transcript with the shared
  transcript reader and writes the file; `--dir` backfills a folder and
  removes prompts files whose transcript is gone; `--print` writes to
  standard output. A transcript whose request numbers skip is refused, not
  half written. See `transcript-prompts.info.md`.
- `backup-conversations` runs it after every created or unchanged export, and
  removes the old prompts file on a rename and on a husk's retirement.
- `libs/own-changes-patch.lua` treats `llm-transcripts/prompts/*.txt` as a
  transcript file: it rides along by its project, or by the header of the
  transcript of the same name.
- Tests: `tests/test-transcript-prompts.sh` (31 checks, through the real
  exporter on a fake session store) and a new scene in
  `tests/test-commit-own-changes.sh`.
