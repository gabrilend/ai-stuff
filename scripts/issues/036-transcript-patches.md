# Issue 036: Transcript Patches

## Current Behavior

**Built 2026-09-22.** `transcript-patches` (apply / list / original / verify /
new / translate-ids), `libs/exact-text.lua`, and the exclusion list
`transcript-patches.exclude` exist; `backup-conversations` applies each
conversation's patches to every rendering before its unchanged check, so
`rederive-transcripts` (which runs the exporter) does too.
`tests/test-transcript-patches.sh`: 35 checks.

`translate-ids --all` over the monorepo (about 50 s) found 485 transcripts:
24 conversations quote ids the graft replaced and received an id patch, 53
quote none, 408 are frozen (session log gone, never re-exported, so the
translation `c6285e303` already made in them cannot be undone by an export),
none excluded. For 76 of the 77 re-renderable transcripts, raw rendering +
patches equals the file on disk. The one mismatch,
`filesystem-tapestry/llm-transcripts/jul-15-26.md`, is not a patch problem:
it was written by an older exporter (no "Models" line, older wrapping), and
its conversation is recorded under a different project, so this project
never re-exports it (it is the transcript `check-transcripts-are-filed-right`
already reports as misfiled).

A first version (committed as `929afaa0a`) kept Lua patch files at two
levels, including a repository-wide folder whose patch 001 translated every
transcript in the monorepo. The owner's answers replaced it with the
per-conversation layout below; the repository-wide level is gone.

Before any of this, a transcript was only a rendering: `backup-conversations`
turns a Claude Code session log into `llm-transcripts/<date>.md` and
re-renders it whenever that session is exported again, so a hand edit lasted
only until the next export. The first edit that needed to last was the
history graft (delta-version issue 031): commit `c6285e303` rewrote 670
quoted ids in 87 files, 66 of them transcripts, while the session logs keep
the old ids.

## Intended Behavior

Any text in a transcript, exactly as the exporter writes it, can be replaced
with other text, written exactly as it should appear, and the replacement is
re-applied every time the transcript is exported again.

- **Per conversation.** A patch belongs to one conversation, found by the
  conversation id in the transcript's header.
- **Idempotent.** Patches are applied to the fresh raw rendering, and a patch
  applied to text that already carries it changes nothing.
- **Stale is an error.** A patch whose find text is gone and whose
  replacement is not there either fails that conversation's export, naming
  the patch; the transcript on disk is left exactly as it was.
- **Honest.** The unpatched original can always be remade from the session
  log (never over the transcript), each transcript can list its patches with
  their dates and reasons, and verify re-renders, re-patches and compares.

## Suggested Implementation Steps

1. **Layout**: `<project>/llm-transcripts/.patches/<conversation-id>/<NNN-short-name>/`,
   applied in name order. Hidden, so the naming rulebook never sees it.
2. **Text patch**: `find` (exact bytes, multi-line, no escaping), `replace`
   (exact bytes), `about` (`YYYY-MM-DD <reason>`). Every occurrence of find is
   replaced. Files are taken byte for byte: a final newline in `find` is part
   of the match, and `new` copies its input files exactly rather than adding
   or stripping one. States: find present → replace all; find absent and
   replace present (or replace empty, a deletion) → applied; neither → stale.
   A replacement containing its own find text changes only occurrences
   outside existing replacements, so re-applying never grows the text.
3. **Id patch**: `ids` (`old new` full ids), `about`. Quoted ids are
   recognised and rewritten by `delta-version/scripts/libs/commit-id-quotes.lua`,
   the graft's own recogniser. States: an old id quoted → translate; none, but
   a new id quoted → applied; neither → stale.
4. **Literal core**: `scripts/libs/exact-text.lua` (count, replace).
5. **Commands**: `apply` (the exporter's call, all or nothing), `list`,
   `original`, `verify`, `new` (records a numbered text patch, refusing a find
   that does not occur in the conversation's transcript as it stands), and
   `translate-ids`.
6. **Exporter**: `export_one_log` runs `apply` on the temp rendering after the
   parser, before the unchanged check; a failure fails that conversation.
7. **Graft translation**: `translate-ids [--exclude <id>]... --all | <project>...`
   renders every conversation that still has a session log, writes an id
   patch (only the ids that conversation quotes) for each that quotes an old
   id, refreshes existing ones in place, and checks raw + patches against
   every re-renderable transcript. Conversations listed in
   `scripts/transcript-patches.exclude` (or `--exclude`) never get one.
8. **Tests**: text states, byte-for-byte newlines, the growing replacement,
   deletion, id states, malformed folders, the exporter path, `new`, and the
   generator with an exclusion.

## Design Decisions

- **Per conversation, per the owner** ("the patches should be on a
  per-conversation basis"). A patch lives with the transcripts it changes and
  is committed with them.
- **Every occurrence, no declared count** ("just re-apply it every time we
  expect it to be overwritten. It's important that it's idempotent"). A
  count would make a patch on a still-growing conversation go stale as the
  text recurs; idempotency comes from the applied-state check instead.
- **Id patches are their own kind, not generated find/replace pairs.** A
  commit id is a short run of hex digits; a plain substring replacement of
  `df8412d0` would also rewrite that string inside a longer id or hash that
  merely begins with it. The graft's recogniser only rewrites ids with
  nothing alphanumeric on either side that resolve to exactly one commit, and
  the per-conversation `ids` file still lists every id the patch touches.
- **Frozen transcripts get no id patch.** They are never re-rendered, so the
  translation already in them is permanent; a patch there could never be
  applied or verified.
- **Exclusions are a file beside the tool**, so the list is committed and
  reviewable; the conversation that planned and ran the graft is its first
  entry, since it quotes the old ids to tell the story.
- **Two copies of the literal rule stay**, per the owner: this library, and
  the upstream-patch skill's stand-alone `replace-exactly.lua`, which is a
  template copied into other projects.
- **Commands live in `scripts/`** beside the exporter; remaking the original is
  the exporter's parser run with patches off.

## Open Questions

None open. Answered 2026-09-22:

1. Count strictness: no count; every occurrence, re-applied on every export,
   idempotent.
2. Patch 001 and the rewrite's own story: patches are per conversation, and
   the graft conversation is excluded from `translate-ids`.
3. The two copies of the literal rule: keep both.

## Related

- delta-version `issues/completed/031-import-project-histories.md` — the graft
  whose id translation `translate-ids` carries forward.
- `issues/034-export-only-the-session-that-stopped.md`,
  `issues/025-capture-subagent-session-logs.md` — the exporter this hooks into.
- The upstream-patch-system skill — the model: literal edits, already-applied
  checks, stale patches as errors.
- The transcript-care skill — how to add a patch and see the original.
