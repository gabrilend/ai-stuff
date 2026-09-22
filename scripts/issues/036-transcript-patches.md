# Issue 036: Transcript Patches

## Current Behavior

**Built 2026-09-22; open on the questions below.** `transcript-patches`
(apply / list / original / verify / new), `libs/exact-text.lua`, and patch 001
at the monorepo root exist; `backup-conversations` applies patches to every
rendering before its unchanged check, so `rederive-transcripts` (which runs
the exporter) does too. Checked on real data: a fresh rendering of
`games/enheim-tome/llm-transcripts/sep-1-26.md` differs from the committed
file in 12 lines of old ids, and with patch 001 applied `verify` reports an
exact match (likewise two other transcripts the quote commit rewrote). The
patch step takes about 0.2 s on the largest transcript (3 MB).
`tests/test-transcript-patches.sh`: 22 checks.

Before this, a transcript was a rendering: `backup-conversations` turns a Claude Code session
log into `llm-transcripts/<date>.md`, and re-renders it whenever that session
is exported again (after every reply for a live session; for every session on
`--all` or `rederive-transcripts --write`). Any hand edit to a transcript
therefore lasts only until the next export, which silently writes the raw
rendering back over it.

The first edit that needed to last is the history graft (delta-version issue
031, 2026-09-22): the trunk's commit ids changed, and commit `c6285e303`
rewrote 670 quoted ids in 87 files, 66 of them transcripts. The session logs
still hold the old ids, so re-exporting any of those sessions puts the old ids
back. There is no record, beside a transcript, of what was changed in it or
why, and no way to see what the export produced before the change.

## Intended Behavior

Edits to transcripts are **patches**: small data files kept beside the
transcripts they change, each with a date and a reason. The exporter renders
the raw transcript, applies every patch that targets it, and only then writes
the file, so a patch is re-applied on every export and never lost.

- **Idempotent.** Patches are applied to the fresh raw rendering, so applying
  them is the same act every time. A patch can also be applied to a file that
  already carries it: it recognises its own result and does nothing.
- **Stale is an error.** A literal patch declares how many times its text
  occurs. If the raw rendering holds a different number, and the patch's
  result is not already there, the export of that conversation fails loudly,
  naming the patch and the file, and the transcript already on disk is left
  exactly as it was. Nothing is skipped quietly and nothing reverts quietly.
- **Honest.** For any transcript, one command remakes the original, unpatched
  rendering from the session log (to a named file or standard output, never
  over the transcript), and another lists the patches the transcript carries,
  with their dates and reasons. A verify command re-renders, re-patches and
  compares with the file on disk.

Two kinds of patch:

- **replace** — literal text, found by comparing characters (no pattern
  language), replaced only if it occurs exactly the declared number of times.
- **commit-map** — translate quoted commit ids through a map of old id to new
  id, using the same recogniser as the graft
  (`delta-version/scripts/libs/commit-id-quotes.lua`). The graft translation is
  patch 001.

## Suggested Implementation Steps

1. **Where patches live.** Two levels, applied in this order:
   - **repository-wide**, `<repository root>/.transcript-patches/*.lua`, for
     edits that follow from an event in the repository's own history (the
     graft) and so apply to every project's transcripts in that repository;
   - **per project**, `<project>/llm-transcripts/.patches/*.lua`, for edits
     to particular conversations.

   Both are hidden folders, so the transcript-naming rulebook (which only
   looks at `*.md` headers) never mistakes a patch for a transcript. Within a
   level, patches apply in file-name order; the file name starts with the
   patch's number.
2. **Patch format.** A Lua file returning one table, loaded with an empty
   environment so it can hold data only: `id`, `date`, `reason`,
   `applies_to` (`"all"` or a list of conversation ids, taken from the
   transcript's header), `kind`, and the kind's fields (`old`, `new`, `count`
   for replace; `map`, a path relative to the repository root, for
   commit-map). Unknown kinds, missing fields, or an `id` that disagrees with
   the file name are errors.
3. **The literal core** goes in `scripts/libs/exact-text.lua`: count
   non-overlapping literal occurrences, and replace only on an exact count.
   Same rules as the upstream-patch skill's `replace-exactly.lua`, as a
   library the patch tool calls in-process. The skill keeps its own copy
   because it is a template copied into other people's projects and must stand
   alone.
4. **The tool**, `scripts/transcript-patches` (LuaJIT), with modes:
   `apply <transcripts-dir> <conversation-id> <file>` (used by the exporter,
   in place, all-or-nothing), `list <transcript>`, `original <transcript>
   [<out>]`, `verify <transcript>...`, and `new` (scaffold a numbered replace
   patch from two text files, counting the old text in the transcript).
5. **Wire it into the exporter.** `export_one_log` applies the patches to the
   temp rendering after the parser succeeds and before the unchanged-content
   check, so an unchanged conversation still reads as unchanged. A failed
   patch fails that conversation's export and leaves its file alone.
   `rederive-transcripts` goes through the exporter, so it is covered too.
6. **Patch 001**: `.transcript-patches/001-commit-ids-after-history-graft.lua`
   at the monorepo root, kind commit-map, applies to all.
7. **Tests**: raw rendering, replace, commit-map, stale, already-applied,
   idempotency, original remake, and an exporter run over a fixture session
   in a scratch repository.

## Design Decisions

- **Per-project and repository-wide, not one central registry.** Patches sit
  in the same repository as the transcripts they change, so they are committed
  together and a project carries its patches wherever it goes. The graft is a
  fact about a repository's history, not about any one project, so it lives
  once at the repository root rather than copied into forty projects.
- **Keyed by conversation id, not file name.** A transcript's file name
  changes when its span of dates grows; its conversation id, recorded in the
  header, does not.
- **Applied to the raw rendering.** This is what makes re-export idempotent
  without any marker text inside transcripts. The already-applied check is a
  second line of defence, for applying a patch to a file written before the
  patch existed.
- **The honesty commands live in `scripts/` beside the exporter**, not in
  delta-version: every transcript tool has one home there (see the
  transcript-care skill), and remaking the original is the exporter's parser
  run with patches off.

## Open Questions

1. A replace patch targeting a conversation that is still growing may see its
   text occur more often as the conversation goes on, which makes the patch
   stale. Should replace patches be limited to finished conversations, or
   should a patch be able to say "at least N"?
2. The history rewrite's own story is told in transcripts that quote the old
   ids on purpose ("main moved from df8412d0 to …"). This session's transcript
   lives in `~/.claude/claude-code`, outside the monorepo, so patch 001 does
   not reach it; but a monorepo transcript describing the rewrite would have
   its old ids translated too. Should patch 001 exempt particular
   conversations?
3. The skill's `replace-exactly.lua` and `libs/exact-text.lua` now hold the
   same rule twice. Keep both (the skill copy is a stand-alone template), or
   have the skill point at this library?

## Related

- delta-version `issues/completed/031-import-project-histories.md` — the graft
  whose id translation is patch 001.
- `issues/034-export-only-the-session-that-stopped.md`,
  `issues/025-capture-subagent-session-logs.md` — the exporter this hooks into.
- The upstream-patch-system skill — the model: exact-count literal edits,
  already-applied checks, stale patches as errors.
- The transcript-care skill — how to add a patch and see the original.
