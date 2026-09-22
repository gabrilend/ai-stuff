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
| **056** (056b–d) | Recursive transcript summarisation | 056a (llama.cpp client) exists. Is the local-model summariser still wanted, now that Claude can summarise transcripts inside a skill? |
| **048** | Issue phase detection utility | The progress dashboard and `git-history.sh` both now read phases from issue filenames and `phase-N/` folders. Is a separate utility still needed, or is 048 answered by those two? |
| **005** | Configure branch isolation | Partially complete; the worktree architecture (041, 046) may have replaced what is left. |
| **027** | Basic reporting framework | The project census (`scripts/census-projects.lua`) produces the monorepo tables; check what 027 adds beyond it. |

## TIER 3: Large specifications, nothing built

| Issues | What | Note |
|--------|------|------|
| 051, 051a–g | Documentation generated from git history | Detailed; most of the reasoning steps could be done by Claude in a skill instead of an Ollama pipeline. |
| 053, 053a–f | Cross-project roadmap coordinator | Same observation; 053b and 053f have a few boxes ticked. |
| 049, 049a–d | Transcript viewer at several levels of detail | Overlaps the transcript tooling in double-diaper-dungeon (transcript-to-HTML). |
| 040, 040a–i | Self-revising CLAUDE.md | Overlaps Claude Code's own memory and CLAUDE.md handling. |
| 044 | Project directory tree generator | Ready; low urgency. |
| 052 | Ollama connection configuration | Requires the owner's verbose confirmation before any change. |
| 017–022 | Ticket distribution system | 016 (markup) is done; the chain after it is unbuilt. |
| 038 | TUI panel abstraction | One box ticked; the bash TUI libraries are being retired in favour of the Lua menu. |
| 039 | Multi-location ai-stuff integration | Unstarted. |

## TIER 4: Aspirational

| Issue | What |
|-------|------|
| 032 → 033 → 034 | Donation links, revenue sharing, bug bounties — product ideas rather than tooling. |
| 002, 003 | Master/reference issues for gitignore unification and ticket distribution. |
| 001-comprehensive-git-repository-setup | Master/reference issue for the repository layout. |

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
