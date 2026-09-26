# Conversation Summary: agent-a2a9ba576474d96c0

Generated on: 2026-09-26 11:56:51
Models: claude-opus-5-5

--------------------------------------------------------------------------------

### User Request 1

READ-ONLY audit. Do not edit, move, or commit anything. Do not cd; use absolute
paths.

Project: /mnt/mtwo/programming/ai-stuff/world-edit-to-execute (a WC3-compatible
game engine; Lua/LuaJIT + C). Open issues in issues/, completed in
issues/completed/. Docs: docs/roadmap.md, docs/wc3-engine-architecture.md,
docs/wow-client-bridge.md, docs/postmortem-azerothcore-integration.md,
notes/vision. issues/progress.md is large; grep it.

Audit these OPEN issues (mostly future phases, not started): 601-609, 801,
801a-h, 901-912, 1001, W01-W08 (incl W05a-e), X01, plus the odd non-standard
files B01-the-phantom-priority.md, GUILD-ROSTER.md, Q00-adventurer-quest-log.md,
CRITICAL-PATH.md, phase2-work-order.txt, and the issues/analysis and
issues/archive directories.

For EACH, determine:
- status (not started / partially done — check source tree and git log per
  file)
- whether it's been superseded or contradicted by later decisions. Specifically
  check: Phase 6/8 issues written Jan 2026 vs the Sep 2026 issues
  603/609/801f/803/804 and Phase W (does WoW-client-as-host change Phase 8
  matchmaking or Phase 6 asset download?); 801h depends on "701 sub-issues"
  (phase 7 was archived — stale reference?); 802 depends on my-libs
  threadpool; Phase 9 editor vs anything; X01 HotS mod generator relevance;
  whether B01/GUILD-ROSTER/Q00 are live or relics; whether CRITICAL-PATH.md
  reflects current reality.
- stale dependency references (issues that point at renamed/retired/archived
  issues)
Report a compact table: issue | status | supersession/staleness evidence |
recommendation (keep / rewrite / retire / merge). Then a short paragraph on
which future phases look coherent vs. drifted. Cite paths. Keep under ~1000
words.

--------------------------------------------------------------------------------

### Assistant Response 1

I sent the full audit table back through the handback. I only read files;
nothing was edited, moved or committed. Almost every audited issue is not
started. The exception is the pathfinding bug in B01, which is still in the
code.

**Out of date or contradicted:**
- **Phase 6 is half-updated.** Issues 603, 609 and 801f took the 2026-09-23
  decision to move all asset files over rmail. 607 is still an HTTP file server
  built on 603's replaced protocol, and 608 still tests "mock file servers".
  601's asset lookup leaves out the player's own WC3 install and the WoW client
  (which W03a now expects) and names a different storage folder from the
  roadmap.
- **Phase 8 has drifted the most.**
  - 801 was updated for the 2026-09-25 "host holds the truth, no lockstep"
    decision. It still assumes connections straight between players, set up by
    getting through home routers.
  - 801a defines its own message format that ignores 803's. 801b–801h still
    say "Phase 7" in their headers.
  - 801h depends on "701 sub-issues", and Phase 7 is archived, so that link is
    dead.
  - 802 is really render threading: it overlaps 512f and the 515/515k
    ceramic-engine benchmarks, and its dependency list is out of date.
- **Does the WoW client as host change Phase 8?** Partly. When the WoW client
  hosts, players find the game through the WoW server's login and realm list, so
  the 801 matchmaker only matters for the engine's own client. None of the
  documents says so.
- **The bigger unsettled question** is how three server designs relate: 803's
  server inside the engine, W02e's rules shim on AzerothCore, and W08's own
  server speaking the WoW protocol. W08 already calls the shim "a stage-1 bridge
  only".
- **Phase 6 asset download** isn't contradicted by Phase W. It just needs 601's
  lookup order updated.
- **911 (map export)** still has WoW-mode formats from before the pivot (`.wex`,
  `.wowmap`). X01 depends on 911.
- **Phase W bookkeeping:** W07's dependencies and the roadmap's Phase W table
  leave out W05a–e and W08. The roadmap still says "Eluna" where W02 now says
  ALE.
- **Phase 7 still looks active in two places:** `docs/roadmap.md` presents
  701/702 as live issues and `issues/progress.md` lists them as Pending. The
  progress file's phase table does correctly say "Archived".

**The odd files:**
- **B01** is a real bug, unchanged in `src/runtime/pathfinding/astar.lua` lines
  355–358. It's slightly worse than described: a better path to an
  already-queued node never gets a better place in the queue.
- **GUILD-ROSTER.md** is a relic: it shows B02/B03 as unclaimed, but both are
  completed.
- **Q00** is an onboarding relic, but the file paths it points to still exist.
- **CRITICAL-PATH.md** is out of date. Its content stops at the 2026-01-07 pivot
  and it still tracks archived Phase 7 items.
- **phase2-work-order.txt** is fully done. **issues/analysis/** is history for
  completed issues. **issues/archive/** is the intended archive.

**Coherent vs drifted:** Phase 9 (the editor) and Phase W hold together; Phase
9's only problem is the WoW leftovers in 911/912. Phase 6 needs one pass to
retire or fold in 603 and 607 and fix 601. Phase 8's January 801 family needs
rewriting around 803.

**Suggested actions, most valuable first:**
1. Decide whether 803's server, the AzerothCore rules shim and W08 are one
   simulation behind different front ends; the answer settles what 801a and 801d
   become.
2. Retire or fold 603 and 607 into the rmail design, and rewrite 601's lookup
   order.
3. Fix the dead and wrong links: 801b–801h headers, 801h's dependency on 701,
   W07's dependencies, and the roadmap and progress tables.
4. Merge 802 into 512f.
5. Retire or move GUILD-ROSTER, CRITICAL-PATH and phase2-work-order.

**Open questions for you:**
1. Does the rmail-only rule for assets also cover maps that the map browser
   (1001) would download over HTTP from public sites?
2. Should X01 (the Heroes of the Storm mod generator) stay among the active
   issues, or be parked as research?

--------------------------------------------------------------------------------

