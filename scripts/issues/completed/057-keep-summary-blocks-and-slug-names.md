# Issue 057: The exporter keeps a summary block and a slug name

## Status
- **Priority**: Medium
- **Type**: Fix / Integration
- **Status**: Completed
- **Created**: 2026-11-03
- **Routed from**: delta-version issue 056c (summary applier, PR #159)

## Current Behavior

delta-version's `apply-summary.sh` (056c) does two things to a transcript.
It writes a summary block under the header line: `<!-- transcript-summary v1 -->`,
`## Session Summary`, the paragraph, a blank line, and an 80-dash separator.
When configured, it also renames the file to `<slug>-<date>.md`. The
exporter (`backup-conversations`) undid both:

- `transcript_body_fingerprint` counted the block, so an unchanged
  conversation looked changed and was rewritten without its block.
- The claim check compared the claimed file's name with a freshly derived
  `<date>` name, so `<slug>-<date>.md` was renamed back to `<date>.md`.
- `transcript_is_new_format` refused `<slug>-<date>.md`, so the applier held
  every rename back.

## Intended Behavior

A summarised transcript of an unchanged conversation is left exactly as it
is. A slug name survives every re-export, and only its date part follows
the conversation.

## Suggested Implementation Steps

1. [x] `transcript_is_new_format` accepts words (lowercase letters and digits
       joined by single dashes) in front of the date.
2. [x] A new `transcript_name_words` gives the words in front of a name's date.
3. [x] The exporter's claim keeps those words and re-derives only the date.
4. [x] The fingerprint steps over a whole summary block on line 2.
5. [x] Tests: `tests/test-transcript-summary-block.sh`.

## What Happened

**2026-11-03.** Built as asked in 056c's note to the scripts project. Tests:
`tests/test-transcript-summary-block.sh` (24 checks; 13 fail on main). The
export guards (14/0) and transcript patch (35/0) suites still pass. The
sessions suite gives 31/2, the same two root-user log failures as on main.

Decisions:

- **The block counts only when it is whole and on line 2.** That is where
  the applier puts it. A marker anywhere else, or one with no closing
  separator, counts as ordinary text. A broken block therefore never hides
  real content from the comparison.
- **Words in front of the date are kept, whoever put them there.** Words come
  from two places: a helper's task words, which the exporter derives itself
  and which are therefore the same, or the applier's slug. Re-deriving the
  whole name is what renamed slug files back. The words must be lowercase
  letters and digits joined by single dashes, and the name must end in a
  date, so an old or hand-made name with no date is still re-derived as
  before.
- **A changed conversation is rewritten without the block.** The comparison
  only keeps the block on an unchanged conversation, as 056c asked. A
  summary of the old content would be stale. The applier's table of contents
  keeps the summary, and 056d decides when to summarise again.
- **The constants live in `transcript-discovery.sh`**
  (`TRANSCRIPT_SUMMARY_MARKER`, `TRANSCRIPT_SUMMARY_END`). They are the same
  strings as `apply-summary.sh`'s `SUMMARY_MARKER` and `SEPARATOR`.
  delta-version was not edited.

## Renumbered

**2026-11-04:** this issue was 043, a number main gave a different issue in
the 2026-11-03 push, so it moved to the next free number, 057.
