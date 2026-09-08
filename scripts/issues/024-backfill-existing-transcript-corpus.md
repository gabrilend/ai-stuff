# Issue #024: Decide whether the existing transcript corpus is re-derived

## Current Behavior

Issues #019, #021, #022, and #023 each describe a change to how transcripts are
produced. All four only affect transcripts written **after** they ship. Every
transcript already on disk keeps whatever defects it was written with.

Re-deriving an existing transcript requires its session log, and session logs
are deleted on a retention schedule. The retention window is now 20 years
(`cleanupPeriodDays` set to 7300 in `~/.claude/settings.json`), but that
setting was applied on 2026-08-03 and does not restore anything already
removed under the previous 30-day default.

### The decisive measurement

Every transcript this exporter writes carries its source conversation's id in
its first line, so a transcript can be matched against the session logs still
present under `~/.claude/projects/`. A project's logs are found by flattening
its absolute path into a single directory name, so the question "can this be
rebuilt?" is answered per project, then per conversation within it.

Counted across every project on the machine that holds an `llm-transcripts/`
folder, excluding git worktrees and backup mounts — re-derive these numbers
with `rederive-transcripts`, which reports and writes nothing by default:

| measure | count |
| --- | --- |
| projects holding transcripts | 61 |
| **projects whose session logs survive — repairable** | **40** (246 transcripts) |
| **projects whose logs are gone — frozen permanently** | **21** (401 transcripts) |
| transcripts actually rebuilt in the first pass | 124 |

The gap between 246 and 124 is conversations whose own log is gone inside a
project that still has others.

These numbers are far better than when this issue was written, and the reason
is worth recording: the retention window was raised from the 30-day default to
20 years (`cleanupPeriodDays` in `~/.claude/settings.json`) on 2026-08-03.
That change could not restore anything already deleted, but everything logged
since has survived, so the repairable share grows on its own from here.

Some transcripts carry no conversation-id header at all. They are derived
outputs or hand-written notes, not products of this exporter, and the naming
rulebook (`libs/transcript-discovery.sh`) already excludes them from anything
it touches.

A worked example of what "frozen" means in practice: the two lost design notes
catalogued in issue #019 sit in
`delta-version/llm-transcripts/jul-25-26-through-jul-26-26.md`. That project's
logs survive, so those particular notes are recoverable. Nothing guarantees the
same for older losses, and there is no way to enumerate what was lost from the
frozen set, because enumerating it would require the logs that are gone.

### Why re-deriving is not simply safe

The exporter is the single naming authority for the corpus, established in
`issues/completed/020-transcript-export-race-guard-and-single-naming-authority.md`.
It re-derives a transcript's name and content from its log on every run and
enforces the result. A re-derivation pass is therefore not a new mechanism —
it is the existing mechanism, run deliberately over a wider set. That is
reassuring for correctness and unhelpful for safety: the same run that repairs
a file also overwrites it, and the overwritten version is the only copy of
whatever it contained.

Two specific ways a re-derived transcript will differ beyond the intended
repairs:

1. **User request numbers shift.** Issue #022 drops envelope traffic that
   currently consumes numbered slots. Any transcript re-derived under the new
   classification will renumber, so a reference to "User Request 8" in one
   version points somewhere else in the other.
2. **Content the current exporter kept may be dropped.** The classification in
   issue #022 is a judgement about what belongs in a narrative. Applying it
   retroactively applies today's judgement to a record written under a
   different one.

## Intended Behavior

**Decided: repair the reachable, leave the rest alone.** Of the three positions
below, the second was chosen. The first pass ran on 2026-09-08, rebuilding 124
transcripts across 40 projects and touching none of the 401 frozen ones.

The decision was forced by issue #026 rather than taken in the abstract. That
issue fixes a defect in the line-splitter which had put a phantom blank line
after every source line in every transcript ever written — roughly 5% of the
corpus by line count. Unlike the earlier four changes, this one is purely
cosmetic: it removes blank lines and marks quoted ones. Nothing is renumbered
and no content is dropped, so the objection that a repair applies today's
judgement to an older record does not arise for it.

The three positions, for the record:

**Forward-only.** The fixes apply to new transcripts. Existing files are left
exactly as they are, as the artifact of the tooling that made them. The corpus
becomes visibly inconsistent — a reader can tell which era a transcript came
from — and that inconsistency is itself an honest record. This matches the
project's append-only instincts most closely.

**Repair the reachable.** Run the exporter over the transcripts whose logs
survive, accepting that the corpus ends up in two states. Recovers the design
notes issue #019 identified as lost, at the cost of a corpus where recent files
follow different conventions from old ones.

**Repair the reachable and mark the rest.** As above, plus a note in each
unrepairable transcript recording that it was produced by an earlier exporter
and which known defects it may carry. Makes the inconsistency explicit rather
than leaving a reader to discover it. Costs an edit to files that are otherwise
frozen, which is itself a rewrite of the historical record.

## Suggested Implementation Steps

1. **Report before writing.** A pass lists which projects it would rebuild and
   which are frozen, and writes nothing, unless explicitly told to write. This
   is `rederive-transcripts` with no arguments.

2. **Skip what is not a project.** A git worktree is a second checkout of a
   repository already in the list, so rebuilding through one writes the same
   project twice onto whatever branch that worktree has out. A backup is a copy
   taken to preserve what a file used to be, and rewriting it destroys the only
   thing it was for. Both are recognised by a path segment rather than by
   inspecting the directory, because the cost of a wrong guess is asymmetric:
   skipping a real project loses nothing a later run cannot do, and writing
   into a backup cannot be undone.

3. **Rebuild through the exporter, never around it.** The exporter is the
   single naming authority; a pass is that program run over a wider set. The
   identity rules in `libs/transcript-discovery.sh` treat the header as the
   source of truth and the filename as a projection, which is why a rebuilt
   conversation that has since run into another day is re-placed under a wider
   date span rather than duplicated. Four files moved that way in the first
   pass, each keeping its conversation id.

4. **Do not touch files without a conversation-id header.** Derived outputs and
   hand-written notes are outside this system, and a pass that mistakes one for
   a transcript destroys something no log can regenerate.

5. **Leave the frozen set alone** unless the third position is later chosen,
   and if it is, treat the annotation as an append rather than a rewrite.

## Related Documents and Tools

- `rederive-transcripts` — the pass itself: finds every project holding
  transcripts, reports which can be rebuilt, and rebuilds them on request.
- `backup-conversations` — the exporter the pass drives; a repair is this
  program run over a wider set, not a new program.
- `libs/transcript-discovery.sh` — the shared rulebook for transcript identity
  and naming that any pass must read through.
- `issues/completed/020-transcript-export-race-guard-and-single-naming-authority.md`
  — records what happened the last time a second program wrote transcript
  names, and why the migrator it describes was retired.
- `issues/026-mark-quoted-lines-in-transcripts.md` — the change that forced
  this decision, and the only one so far applied retroactively.
- `issues/019-preserve-askuserquestion-in-transcripts.md`,
  `issues/021-strip-terminal-escape-codes-from-transcripts.md`,
  `issues/022-classify-harness-envelope-traffic.md`,
  `issues/023-record-model-provenance-as-narrative-beats.md` — four further
  changes whose retroactive application this issue also governs. None has been
  applied retroactively yet; #022 in particular renumbers requests, which is
  the case this issue's caution was written for.

## Metadata

- **Priority**: decided and first pass complete; reopens whenever another
  exporter change is judged safe to apply backwards.
- **Complexity**: Low mechanically, high in consequence. The pass is an
  existing program run over more files; the decision it enacts is irreversible
  outside git.
- **Dependencies**: A change worth applying backwards. #026 was the first.
- **Impact**: 124 transcripts rebuilt; 401 unreachable regardless. The
  repairable share grows on its own now that logs are kept for 20 years.

## Success Criteria

- Every transcript whose log survives reflects the current exporter's output.
- No transcript whose log is absent is modified.
- No file lacking a conversation-id header is touched.
- Nothing inside a git worktree or a backup is written.
- The pass is a single git commit, revertible in one operation.

## Open Questions

1. **Do we want to do any of this at all?** *Yes, for cosmetic repairs.* The
   argument against — that a consistently old-format archive beats a mostly-old
   one with a recent patch — carries weight for changes that alter what a
   transcript says. It carries much less for one that only removes blank lines
   the tooling should never have written.
2. **Which of the three positions?** *Repair the reachable.* See above.
3. **Does re-deriving a transcript violate the project's append-only
   principle?** *Not for a cosmetic pass.* Re-deriving replaces a record with a
   better record of the same events. The project's rules point both ways — *if
   you find a mistake, fix the docs* against *append-only memory, no editing
   possible* — and the line drawn here is whether the words change. Blank lines
   and quote markers are not words. Renumbering and dropped content would be,
   which is why #022 is still not applied backwards.
4. **Is the renumbering acceptable?** *Not yet answered, and not yet needed.*
   No pass has renumbered anything. This must be settled before #022 is applied
   retroactively, not before then.
5. **Should the reachable set be repaired individually rather than in a pass?**
   *In a pass.* The set is now far too large to inspect one at a time, and the
   project's rule is to build the tool rather than do things by hand.
6. **What happens to the transcripts of sessions that are still live?** *They
   are already handled and need no special case.* A live session's transcript
   is rewritten on every Stop hook anyway, so it adopts new behaviour without a
   pass; a pass that reaches one simply does early what the hook would do next.
7. **Should anything be done to prevent this situation recurring?** *Already
   done, for logs created from here on.* The retention window is 20 years
   rather than 30 days. It protects nothing that was already deleted, and holds
   only as long as that setting survives.
8. **What reaches the 401 frozen transcripts?** *Nothing, as things stand, and
   this is the one question the decision leaves open.* Their session logs are
   gone, so the exporter cannot rebuild them. A rewriter working on the
   transcript files themselves could in principle apply the cosmetic parts of
   #026 — both the blank-line collapse and the quote marking, since a
   transcript contains both sides of its own conversation — but it would be a
   second program writing transcripts, which is the exact thing issue #020
   retired a migrator for. Not attempted.
