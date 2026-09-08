-- Part 5: 6 April through 19 May 2026.
--
-- The words live here and nowhere else. build-reports.lua turns this table into
-- the standalone HTML page, the plain-text twin, the index entry and the
-- body-only copy for publishing.

return {

  part = 5,
  slug_name = "written-not-built",
  title = "Written, Not Built",
  eyebrow = "Part 5 · 6 April – 19 May 2026",
  compiled = "compiled 6 Sep 2026",
  dek = "A hundred and seventy-one issue files were written and twelve were "
    .. "finished. A real-time strategy game reaches a playable phase in three "
    .. "days, and then one day in May produces a hundred and twenty-five "
    .. "blueprints for a port nobody has started.",

  totals = {
    { value = "171", label = "issues written" },
    { value = "12", label = "completed" },
    { value = "4", label = "projects" },
  },

  -- {{{ days — weeks, because the window is sparse across six of them
  days = {
    { label = "Apr 6",  value = 5, emphasis = true, month = "April" },
    { label = "13",     value = 0 },
    { label = "20",     value = 0 },
    { label = "27",     value = 17, emphasis = true },
    { label = "May 4",  value = 0, emphasis = true },
    { label = "11",     value = 0 },
    { label = "18",     value = 11, emphasis = true, month = "May" },
  },
  chart_alt = "Commits per week from 6 April to 19 May 2026: five, none, none, "
    .. "seventeen, none, none, eleven.",
  chart_caption = "One column per week. Three working weeks out of seven, and the "
    .. "three do not touch the same project.",
  -- }}}

  -- {{{ intro
  intro = {
    { kind = "lead", text = "Six weeks, thirty-three commits, three working weeks "
      .. "that share no project between them. The poetry website finishes a piece "
      .. "of image work in April, a real-time strategy game is started and taken to "
      .. "a playable state over four days at the end of the month, and on one day "
      .. "in May a vintage-computer project writes a hundred and twenty-five issue "
      .. "files without building any of them." },
    { kind = "thread", name = "Blueprints outnumber code", first = 1,
      text = "This is the extreme case. **171 issue files written, 12 completed** — "
        .. "a ratio of fourteen to one, against roughly two to one across the year. "
        .. "The work of this window is almost entirely deciding what to build." },
  },
  -- }}}

  work_caption = "Issue files, 6 April – 19 May",
  -- {{{ work
  work = {
    { name = "apple-IIds",              commits = 125, added = 0,  removed = 0 },
    { name = "games/3d-rts",            commits = 35,  added = 9,  removed = 0 },
    { name = "handheld-mac-plus",       commits = 8,   added = 0,  removed = 0 },
    { name = "neocities-modernization", commits = 3,   added = 3,  removed = 0 },
  },
  -- }}}
  work_note = {
    { kind = "p", text = "Columns are issue files written and completed; the third "
      .. "is unused here. `handheld-mac-plus` is the directory apple-IIds was "
      .. "renamed out of on the same day, so its eight files are the same effort "
      .. "under an older name." },
  },

  projects_caption = "What happened",
  projects = {

    -- {{{ 3d-rts
    {
      id = "rts", name = "games/3d-rts", short = "3d-rts",
      commits = 35, slug = "35 issues written, 9 completed",
      identity = "A real-time strategy game in C against raylib: heightmap terrain "
        .. "seen from a pitched camera, units selected with a box and ordered to "
        .. "move, and the movement running on a task pool rather than a frame loop.",
      stats = {
        { key = "Started",   value = "27 Apr" },
        { key = "To playable", value = "3", note = "days" },
        { key = "Issues written", value = "35" },
        { key = "Completed", value = "9" },
        { key = "Pool tests", value = "9", note = "passing" },
      },
      blocks = {
        { kind = "p", text = "**27 April.** Eight commits take the project from an "
          .. "empty directory to something you can look at and click on: a build "
          .. "system with raylib pinned at a version, a camera at a strategy-game "
          .. "pitch, heightmap terrain, a ray-pick that turns a click into a point on "
          .. "that terrain, a pool of units drawn as boxes, and unit movement with a "
          .. "turn-before-walk feel. raylib was vendored at a pinned version and "
          .. "bumped from 5.5 to 6.0 the same day." },

        { kind = "h", text = "The cycler that silently tied two priorities" },

        { kind = "p", text = "The task pool consults its priority levels on a "
          .. "repeating cycle, and the documented intent is the pattern *1; 1,2; "
          .. "1,2,3; … 1..N* — priority 1 alone forms the first sub-cycle, so it gets "
          .. "one more consultation per period than priority 2." },
        { kind = "p", text = "The implementation started at level 2 and wrapped back "
          .. "to 2, producing *1,2; 1,2,3; …* instead. **Priority 1 and priority 2 "
          .. "were consulted nine times each per period.** The ranking existed in the "
          .. "documentation and not in the machine, and nothing failed — a pool that "
          .. "consults two priorities equally still runs every task. Corrected, the "
          .. "per-period counts are 10, 9, 8 down to 1, and the period length is 55 "
          .. "rather than 54." },

        { kind = "h", text = "29 April · a teleport that was arithmetically correct" },

        { kind = "p", text = "Movement moved onto the task pool. Each moving unit "
          .. "owns a two-action chain that reschedules itself at priority 2; ordering "
          .. "a unit somewhere either spawns that chain or updates the target of the "
          .. "one already running. Because motion is computed from a timestamp rather "
          .. "than a fixed step, the chain can run at any cadence and still cover the "
          .. "right total distance." },
        { kind = "p", text = "Under processor contention some units visibly snapped "
          .. "across the map. The advance function reads the clock at the start of an "
          .. "action and writes that reading back as the unit's last-update time at "
          .. "the end. **A worker preempted mid-action therefore overwrites a fresh "
          .. "timestamp with a stale one**, the next iteration sees a large elapsed "
          .. "time, and computes a step that is correct for that elapsed time and "
          .. "looks like a teleport." },
        { kind = "pull", text = "Both obvious band-aids give up distance "
          .. "correctness, so neither was applied. The snap was left visible, the "
          .. "architectural fix was written up as its own issue, and one issue it "
          .. "superseded was closed on the grounds that its feature falls out of the "
          .. "fix for free." },

        { kind = "h", text = "1 May · the walkthrough written twice" },

        { kind = "p", text = "A six-part narrative companion to the architecture "
          .. "document was drafted from the design-of-record issue alone. Everything "
          .. "in it was true of the plan and wrong about the program: it described "
          .. "coroutines where the pool is an action array, a fully serial simulation "
          .. "where movement was already running on the pool, and it did not mention "
          .. "the snap or the redesign then in flight." },
        { kind = "p", text = "It was rewritten the same day from the full set — nine "
          .. "issues open and completed, the pool library's header, its companion "
          .. "file and the test index — with status markers threaded through every "
          .. "part." },
        { kind = "thread", name = "Documentation drifts from the thing it describes",
          text = "The lesson was written into the issue that anchored the work: "
            .. "**read every related issue, open and completed, before writing about "
            .. "an architecture.** A document sourced from the design of record "
            .. "describes the design of record, which is not the same object as the "
            .. "program." },
      },
    },
    -- }}}

    -- {{{ apple-IIds
    {
      id = "iids", name = "apple-IIds", short = "apple-IIds",
      commits = 125, slug = "125 issues written, 0 completed",
      identity = "An Apple IIgs environment running on the Anbernic RG DS — the "
        .. "same handheld soren-ds targets. Three layers: the handheld's Linux "
        .. "userland at the bottom, a 65C816 staging ground above it, and a "
        .. "bare-metal ARM port of the Apple Toolbox at the top.",
      stats = {
        { key = "In one day", value = "125", note = "issue files" },
        { key = "Completed",  value = "0" },
        { key = "Phases",     value = "12" },
        { key = "Toolbox managers", value = "14" },
      },
      blocks = {
        { kind = "p", text = "**19 May, and only 19 May.** The project is renamed out "
          .. "of an earlier directory, pivots bare-metal work into its core path, "
          .. "and then writes out its phases 2 through 12 as issue files. Nothing is "
          .. "built." },

        { kind = "h", text = "Splitting a multi-year port fourteen ways" },

        { kind = "p", text = "The Apple IIgs Toolbox is a set of managers — Memory, "
          .. "Resource, Loader, Event, QuickDraw, Window, Menu, Control, Dialog, "
          .. "Standard File, Sound, Scrap, Process, Print. Porting it to bare-metal "
          .. "ARM was one issue; it became fourteen sub-issues, ordered by what "
          .. "depends on what: Memory and Resource first because everything is built "
          .. "on them, then Loader and Event, then the interface managers, then the "
          .. "four broadly independent ones." },
        { kind = "p", text = "Two other issues — one for lock-wrapper fixes, one for "
          .. "structural reentrancy fixes — were split the same fourteen ways, **with "
          .. "the letters matched across all three**. So the *a* sub-issue of each is "
          .. "the Memory Manager, and one manager can be traced through the "
          .. "lock-fixes pass, the structural pass and the bare-metal port by holding "
          .. "one letter." },
        { kind = "pull", text = "Several of the structural sub-issues are expected to "
          .. "be no-ops — the audit may find nothing structural in that manager — and "
          .. "they were written anyway, as placeholders, so that the absence of work "
          .. "is discoverable rather than merely absent." },

        { kind = "h", text = "Reading one project's threading through another's needs" },

        { kind = "p", text = "The last commit of the day is a research note on the "
          .. "thread pool belonging to soren-ds, the other project targeting the same "
          .. "handheld, read specifically through this project's requirements. It "
          .. "sorts that pool into three piles: **lifted wholesale** — the pool "
          .. "itself, the initialisation barrier, the priority hook, the "
          .. "thread-local-storage pattern; **adapted** — worker contexts become "
          .. "tasks, and atomic operations become interrupt-disable, because the "
          .. "65C816 has no atomics; and **left behind** — the dataflow dispatch "
          .. "layer, the language specification system, the slot store." },
        { kind = "p", text = "It carries translation tables for both target "
          .. "processors and flags the questions soren-ds has not itself settled: the "
          .. "priority schema, how the large-value heap reclaims, whether worker "
          .. "contexts are cache-line aligned." },
      },
    },
    -- }}}

    -- {{{ neocities
    {
      id = "neo", name = "neocities-modernization", short = "neocities",
      commits = 3, slug = "3 issues written, 3 completed",
      identity = "",
      blocks = {
        { kind = "p", text = "**6–7 April.** Gallery pages for images that stand on "
          .. "their own rather than as attachments to a poem, a configuration "
          .. "reference document, and a separate identifier sequence for reshared "
          .. "posts so their numbering stops colliding with original ones." },
        { kind = "p", text = "Two issue files are written for sources that do not "
          .. "exist yet: pictures served off an Android phone, and conversation "
          .. "starters. The first is the same idea that becomes a whole phase in "
          .. "February and is still unbuilt." },
      },
    },
    -- }}}

  },

  -- {{{ open
  open = {
    { project = "games/3d-rts", state = "Known defect", tone = "blocked",
      waiting = "Units snap across the map under processor contention, because an "
        .. "action writes back a clock reading it took before being preempted. The "
        .. "fix is frame-ring scheduling, written up and not built. **Shipped "
        .. "visible rather than patched**, because both cheap patches trade away "
        .. "distance correctness." },
    { project = "games/3d-rts", state = "Demoted", tone = "open",
      waiting = "An issue for stable unit indices was moved from the next "
        .. "iteration's plan to *exploratory, not committed* — recorded as a change "
        .. "of confidence rather than silently dropped." },
    { project = "apple-IIds", state = "All of it", tone = "open",
      waiting = "125 issue files, zero completed, twelve phases. The Toolbox port "
        .. "alone is fourteen sub-issues described in the tickets as multi-year "
        .. "work. The project does not appear again until June." },
    { project = "neocities-modernization", state = "Written, unbuilt", tone = "open",
      waiting = "Android phone pictures as an image source, and conversation "
        .. "starters as a text source. Both are issue files with no implementation." },
  },
  -- }}}

  -- {{{ tree
  tree = {
    { kind = "p", text = "**No working transcripts survive from this window.** Every later part links the conversations behind each project; these months are inside the hundred and eighty sessions the pruner deleted, so there is nothing to link to. The record here is commits and issue files only." },
    { kind = "p", text = "The three working weeks in this window touch four projects "
      .. "and share none between them. That is unusual: every other part has at "
      .. "least one project running through the whole of it." },
  },
  -- }}}
}
