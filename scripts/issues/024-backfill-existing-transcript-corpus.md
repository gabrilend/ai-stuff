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
present under `~/.claude/projects/`. Counted across the whole corpus:

| measure | count |
| --- | --- |
| transcript files in `ai-stuff/*/llm-transcripts/` | 484 |
| of those, carrying a conversation id in the header | 431 |
| **whose session log still exists — repairable** | **23** |
| **whose session log is gone — frozen permanently** | **406** |

The remaining 53 files carry no conversation-id header. They are derived
outputs or hand-written notes, not products of this exporter, and the naming
rulebook (`libs/transcript-discovery.sh`) already excludes them from anything
it touches.

So **roughly 5% of the corpus can be repaired at all.** The other 95% is
frozen in whatever state the exporter left it, and no change to the exporter
will ever reach it. This is not a limitation of the proposed fixes; it is a
consequence of the source data having been deleted, months ago in most cases.

A worked example of what "frozen" means in practice: the two lost design notes
catalogued in issue #019 sit in
`delta-version/llm-transcripts/jul-25-26-through-jul-26-26.md`. That
conversation's log is one of the 23 still alive, so those particular notes are
recoverable. Nothing guarantees the same for older losses, and there is no way
to enumerate what was lost from the 406, because enumerating it would require
the logs that are gone.

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

Unresolved. This issue exists to hold the decision and its consequences, not
to presume one. The three coherent positions:

**Forward-only.** The fixes apply to new transcripts. Existing files are left
exactly as they are, as the artifact of the tooling that made them. The corpus
becomes visibly inconsistent — a reader can tell which era a transcript came
from — and that inconsistency is itself an honest record. This matches the
project's append-only instincts most closely.

**Repair the reachable 23.** Run the exporter over the transcripts whose logs
survive, accepting that the corpus ends up in two states and that the repaired
5% is the recent end of it. Recovers the design notes issue #019 identified as
lost, at the cost of a corpus where recent files follow different conventions
from old ones.

**Repair the reachable 23 and mark the rest.** As above, plus a note in each
unrepairable transcript recording that it was produced by an earlier exporter
and which known defects it may carry. Makes the inconsistency explicit rather
than leaving a reader to discover it. Costs an edit to 406 files that are
otherwise frozen, which is itself a rewrite of the historical record.

## Suggested Implementation Steps

These apply to whichever repair position is chosen; the forward-only position
needs none of them.

1. **Establish reversibility before anything is overwritten.** The corpus lives
   in git. A commit taken immediately before a re-derivation pass is the only
   thing that makes the pass undoable, and it must include the working tree
   clean, so that the pass's diff is exactly the pass.
2. **Report before writing.** A pass should first list which transcripts it
   would touch and what would change in each, without writing. The number that
   matters — 23 — is small enough to inspect individually, and inspecting it is
   cheaper than reasoning about it in the abstract.
3. **Match by conversation id, never by name.** The identity rules in
   `libs/transcript-discovery.sh` already treat the header as the source of
   truth and the filename as a projection. A repair pass must use the same
   rulebook rather than its own matching, for the reason issue #020 records: a
   second program that names transcripts will fight the exporter and lose.
4. **Do not touch files without a conversation-id header.** The 53 derived and
   hand-written files are outside this system, and a pass that mistakes one for
   a transcript destroys something no log can regenerate.
5. **Leave the 406 alone unless the third position is chosen**, and if it is,
   treat the annotation as an append rather than a rewrite.

## Related Documents and Tools

- `backup-conversations` — the exporter; a repair pass is this program run
  over a wider set, not a new program.
- `libs/transcript-discovery.sh` — the shared rulebook for transcript identity
  and naming that any pass must read through.
- `issues/completed/020-transcript-export-race-guard-and-single-naming-authority.md`
  — records what happened the last time a second program wrote transcript
  names, and why the migrator it describes was retired.
- `issues/019-preserve-askuserquestion-in-transcripts.md`,
  `issues/021-strip-terminal-escape-codes-from-transcripts.md`,
  `issues/022-classify-harness-envelope-traffic.md`,
  `issues/023-record-model-provenance-as-narrative-beats.md` — the four changes
  whose retroactive application this issue governs.

## Metadata

- **Priority**: unset — see Open Questions.
- **Complexity**: Low mechanically, high in consequence. The pass is an
  existing program run over more files; the decision it enacts is irreversible
  outside git.
- **Dependencies**: Meaningless until at least one of #019, #021, #022, #023 is
  decided and implemented.
- **Impact**: At most 23 transcripts improve. 406 are unreachable regardless.

## Success Criteria

Cannot be stated until the position is chosen. Under a repair position:

- Every transcript whose log survives reflects the current exporter's output.
- No transcript whose log is absent is modified, unless annotation was chosen.
- No file lacking a conversation-id header is touched.
- The pass is a single git commit, revertible in one operation.

## Open Questions

1. **Do we want to do any of this at all?** Repairing 5% of a corpus produces
   a corpus that is 95% unrepaired. There is a real argument that a
   consistently old-format archive is more useful than a mostly-old one with a
   recent patch of different conventions.
2. **Which of the three positions above?** Forward-only, repair the reachable,
   or repair and mark. This is the central question and nothing else in the
   issue resolves without it.
3. **Does re-deriving a transcript violate the project's append-only
   principle?** The corpus is treated as a historical record. Re-deriving
   replaces a record with a better record of the same events, which is either
   a correction or a rewrite depending on how the principle is read. The
   project's own rules point both ways: *if you find a mistake, fix the docs*
   argues for repair; *append-only memory, no editing possible* argues against.
4. **Is the renumbering acceptable?** Any external reference to a numbered user
   request in a repaired transcript breaks silently. It is not known whether
   anything currently references transcripts that way.
5. **Should the 23 be repaired individually rather than in a pass?** They are
   few enough to inspect one at a time, which trades automation for the ability
   to notice a bad repair before it is committed. The project's rule is to
   build the tool rather than do things by hand, which argues for the pass.
6. **What happens to the transcripts of sessions that are still live?** A
   session in progress has its transcript rewritten on every Stop hook anyway,
   so it will adopt the new behaviour without any pass. Whether that means live
   sessions should be excluded from a pass, or are simply already handled, has
   not been checked.
7. **Should anything be done to prevent this situation recurring?** The reason
   only 23 remain is that logs were culled under the old 30-day default while
   the transcripts they would have repaired accumulated defects. The retention
   window is now 20 years, which prevents a repeat — but only for logs created
   from now on, and only as long as that setting survives.
