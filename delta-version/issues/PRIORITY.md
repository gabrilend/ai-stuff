# Delta-Version Issue Prioritization

*Rewritten 2026-09-22. The December 2024 version ranked 035, 036, 008,
013–015, 024 and 026 as the work ahead; every one of them has since been
completed, so that ordering is kept only in git history.*

Priorities are judged on:
1. **What it unblocks** — work other issues are waiting on.
2. **Whether it is still the right shape** — several specifications were
   written for a local-model pipeline (Ollama, llama.cpp) before Claude
   Code skills existed; some of that reasoning now belongs inside a skill.
3. **Cost** — effort against value.

For counts of open and completed issues, run the dashboard rather than
reading a number here:
`luajit /home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /home/ritz/programming/ai-stuff/delta-version -t`

---

## TIER 1: Small, unblocking, ready now

| Issue | What | Why now |
|-------|------|---------|
| **055** | Commit gated by issue completion | Rewritten so the gate can work (it sees only the command text) and so it narrows to what the shared line-ledger commit gate does not cover. Small once that gate lands. |
| **042a** | The three unbuilt `check-utilities.sh` audits | The flags are advertised in `--help` and print "not yet implemented"; either build them or remove them. `--issue-standards` should call the shared issue validator rather than hold a second copy of the rules. |
| **046** | Simplify branch architecture | Marked COMPLETED, but three acceptance boxes are unchecked (dev branches merged and deleted; main repo held on master by the post-checkout hook). Check them against the repository and move it to `completed/`, or reopen what is not true. |
| **054** | External library cleanup | Complete except "GitHub language statistics updated", which only a push and time can satisfy. Confirm on GitHub and move it. |

## TIER 2: Worth doing, needs a decision first

| Issue | What | Decision needed |
|-------|------|-----------------|
| **048** | Issue phase detection utility | The progress dashboard and `git-history.sh` both now read phases from issue filenames and `phase-N/` folders. Is a separate utility still needed, or is 048 answered by those two? |
| **027** | Basic reporting framework | The project census (`scripts/census-projects.lua`) produces the monorepo tables; check what 027 adds beyond it. |

## Decided 2026-11-02, being built

Each issue below held a recommendation with its options. Ritz asked that
open questions be answered without waiting on him, so each recommendation
is now the decision; see the issue files. These rows supersede the Tier 3
notes for 070. (052 has since closed as superseded.)

| Issue | What | Decided |
|-------|------|-------------|
| **056** (056d) | Recursive transcript summarisation | 056a–c are done. 056d (the overseer) remains. It waits on the scripts project teaching the rulebook slug names and the summary block. |
| **070** (was 038) | TUI panel abstraction | Build it in the shared `scripts/libs/tui.lua`, owned by the scripts project. The Lua menu is its biggest user and gains as much as the history viewer. Then move delta-version's history viewer onto it. |

## TIER 3: Large specifications, nothing built

| Issues | What | Note |
|--------|------|------|
| 051, 051a–g | Documentation generated from git history | First slice built: `scripts/history-kernel.lua` (051a: first-commit facts from git, and a model-drafted vision that never replaces an existing one). 051b–g remain. |
| 053, 053a–f | Cross-project roadmap coordinator | First slice built: `scripts/todone.lua` (components several projects plan, named by the model, matched by spelling and a synonym list). Fuzzy tiers, the shared roadmap and outputs remain (see 053's status note). |
| 049, 049a–d | Transcript viewer at several levels of detail | First slice built: `scripts/transcript-detail.lua` (049a, model-classed detail levels 1–5, verbatim). Abstraction levels, chapters and the batch pipeline remain (see 049's status note). Overlaps the transcript tooling in double-diaper-dungeon. |
| 040, 040a–i | Self-revising CLAUDE.md | First slice built: `scripts/claudemd-revise.lua` (events, model-worded proposals, approve with backup, rollback, audit). The rest is listed in 040's status note. Overlaps Claude Code's own memory handling. |
| 044 | Project directory tree generator | Ready; low urgency. |
| 052 | Ollama connection configuration | Requires the owner's verbose confirmation before any change. |
| 017–022 | Ticket distribution system | 016 (markup) is done; the chain after it is unbuilt. |
| 070 (was 038) | TUI panel abstraction | One box ticked; the bash TUI libraries are being retired in favour of the Lua menu. |

## TIER 4: Aspirational

| Issue | What |
|-------|------|
| 032 → 033 → 034 | Donation links, revenue sharing, bug bounties — product ideas rather than tooling. |
| 002, 003 | Master/reference issues for gitignore unification and ticket distribution. |
| 068 (was 001-MASTER) | Master/reference issue for the repository layout. |

---

## Blocking relationships that still matter

```
shared issue validator (scripts A04)
        │
        ├──▶ 042a --issue-standards
        └──▶ issue-lifecycle skill

shared line-ledger commit gate (scripts 032)
        │
        └──▶ 055 (narrowed to the issue-completion check only)

016 markup ✅ ──▶ 017 ──▶ 018 ──▶ 019 ──▶ 020 ──▶ 021 ──▶ 022
```
