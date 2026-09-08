-- Progress report data: 3 September through 14 December 2025.
--
-- The first stage of the project, and the only one that predates version
-- control. Built from file modification times rather than commits, because for
-- this period no commits exist. The evidence is weaker and the page says so.
--
-- The words live here and nowhere else. build-reports.lua turns this table into
-- the standalone HTML page, the plain-text twin, the index entry and the
-- body-only copy for publishing.

return {

  part = 1,
  slug_name = "the-first-fourteen-weeks",
  title = "The First Fourteen Weeks",
  eyebrow = "Part 1 · 3 September – 14 December 2025 · from file timestamps",
  compiled = "compiled 2 Sep 2026",
  dek = "The project begins on a Wednesday afternoon with eight Lua files and a "
    .. "design document written after them. Fourteen weeks later it holds "
    .. "twenty-four projects and has outgrown being remembered, and everything goes "
    .. "into version control.",

  totals = {
    { value = "24", label = "projects" },
    { value = "1,023", label = "files written" },
    { value = "14", label = "weeks" },
  },

  -- {{{ days — weeks, in this one
  days = {
    { label = "Sep 1", value = 15, emphasis = true, month = "September" },
    { label = "8",     value = 36 },
    { label = "15",    value = 42 },
    { label = "22",    value = 218, emphasis = true },
    { label = "29",    value = 8 },
    { label = "Oct 6", value = 3, emphasis = true },
    { label = "13",    value = 5 },
    { label = "20",    value = 175, emphasis = true },
    { label = "27",    value = 143, emphasis = true },
    { label = "Nov 3", value = 34, emphasis = true },
    { label = "10",    value = 106 },
    { label = "17",    value = 38 },
    { label = "24",    value = 0 },
    { label = "Dec 1", value = 79, emphasis = true },
    { label = "8",     value = 121, month = "December" },
  },
  chart_alt = "Authored files by the week they were last written, from the week of "
    .. "1 September to the week of 8 December 2025. Peaks of 218 in the week of "
    .. "22 September, 175 and 143 in the last two weeks of October, 106 in mid-"
    .. "November and 121 in the week before the founding commit. One silent week, "
    .. "24 to 30 November.",
  chart_caption = "One column per week, labelled by the Monday it starts. The height "
    .. "is how many surviving authored files were **last written** that week. Four "
    .. "spikes and one silent week — 24 to 30 November, which produced nothing that "
    .. "survives.",
  -- }}}

  -- {{{ intro
  intro = {
    { kind = "lead", text = "The window runs 3 September to 14 December 2025. It is "
      .. "the only part with no commits behind it: everything here is measured from "
      .. "when files were last written, because version control arrives on the last "
      .. "day." },
    { kind = "p", text = "**Why the window starts on 3 September 2025.** The founding "
      .. "commit imported files that already existed, and their timestamps reach much "
      .. "further back — to a notes folder from 2021 and, through vendored libraries, "
      .. "to a Lua distribution from 2001. **None of that is this project.** The "
      .. "earliest file belonging to the work these reports describe was written at "
      .. "25 minutes past two on the afternoon of Wednesday 3 September 2025." },
    { kind = "p", text = "**Why it ends on 14 December.** The next day, all of it goes "
      .. "into git in one commit of 29,157 files, and the record stops being "
      .. "inference. That commit and the four weeks after it are *29,157 Files*." },
    { kind = "p", text = "**How the 1,023 files were arrived at.** Of the founding "
      .. "commit's 29,157 files, 28,905 are still on disk. Dropping vendored "
      .. "libraries, two large imported trees — a console toolchain and a game's "
      .. "source — and everything outside plausibly authored places leaves 2,081. "
      .. "Restricting those to the window leaves **1,023 files across 24 projects**, "
      .. "which is what the charts below describe." },
  },
  -- }}}

  work_caption = "What was being written, by where it sits",
  -- {{{ work
  work = {
    { name = "issue files (tickets and blueprints)", commits = 0, added = 331, removed = 0 },
    { name = "source",                               commits = 0, added = 218, removed = 0 },
    { name = "documents",                            commits = 0, added = 120, removed = 0 },
    { name = "inputs (notes, images, archives)",     commits = 0, added = 59,  removed = 0 },
    { name = "notes",                                commits = 0, added = 48,  removed = 0 },
    { name = "scripts",                              commits = 0, added = 33,  removed = 0 },
  },
  -- }}}
  work_note = {
    { kind = "p", text = "The *added* column is a file count and the *commits* column "
      .. "is zero throughout, because there are no commits in this window — the "
      .. "shared table is being borrowed for a job it was not designed for, which is "
      .. "noted rather than disguised. The remainder of the 1,023 sit at a project's "
      .. "root rather than in any of these folders." },
    { kind = "thread", name = "Blueprints outnumber code",
      text = "**331 issue files against 218 source files**, in the first fourteen "
        .. "weeks, before anybody wrote that rule down. The collection writes what it "
        .. "intends to build in more detail, and more often, than it builds it. Every "
        .. "later part shows the consequence — a project with 94 tickets and no code, "
        .. "a window writing 171 blueprints and finishing 12 — and it is already true "
        .. "here, before git." },
  },

  projects_caption = "What the timestamps show",
  projects = {

    -- {{{ the arc
    {
      id = "arc", name = "the fourteen weeks", short = "the arc",
      commits = 24, slug = "24 projects, 1,023 files",
      identity = "One afternoon in September to the night before version control, "
        .. "with each project drawn from the first day one of its files was written "
        .. "to the last.",
      stats = {
        { key = "Days",       value = "103" },
        { key = "Working weeks", value = "14", note = "of 15" },
        { key = "Projects",   value = "24" },
        { key = "Files",      value = "1,023" },
        { key = "Busiest week", value = "218", note = "22–28 Sep" },
      },
      blocks = {
        { kind = "h", text = "Wednesday 3 September · the first afternoon" },

        { kind = "p", text = "The earliest surviving file is `combat.lua`, written at "
          .. "14:25. Seven more follow it before the evening — a monster, an item, a "
          .. "main entry point, a maze, a hero, a unit — and at 16:32, between the "
          .. "maze and the unit, a plain-text game design document." },
        { kind = "pull", text = "The design document is not the first file. It is the "
          .. "seventh, written two hours into the work, after most of the code it "
          .. "describes." },
        { kind = "p", text = "The project it belongs to is a contest entry, and it is "
          .. "eight files that were never touched again. Nothing in the collection "
          .. "predates that afternoon." },

        { kind = "h", text = "Thursday 4 September · the method arrives" },

        { kind = "p", text = "At 08:50 the next morning, in a different project — the "
          .. "one that lays poetry out as a printable book — a file called `CLAUDE.md` "
          .. "is written. **It is the earliest one anywhere in the collection.** That "
          .. "is the file an assistant reads before doing anything: the conventions, "
          .. "the preferred language, how issues are to be written, what a fallback "
          .. "is and why there should not be one." },
        { kind = "p", text = "**So the working method is one day younger than the "
          .. "work.** The day after the first code, somebody wrote down how the work "
          .. "was to be done. Two more copies of it appear the same afternoon, in "
          .. "nested backup folders, which is the shape of somebody keeping a spare "
          .. "before they trust the arrangement." },
        { kind = "thread", name = "Fallbacks hide bugs", first = 2,
          text = "The conventions file written on day two is where the rule lives: "
            .. "prefer an error to a fallback, and notify every time one is used. "
            .. "**The method is one day younger than the work.** Part 2 is where it "
            .. "first costs ninety-five deleted lines to apply, and four later parts "
            .. "record what applying it caught." },

        { kind = "p", text = "The next day a notes file appears in two projects at the "
          .. "same second — the first trace of a shared notes vault being synced into "
          .. "more than one place. That vault is the thing whose files reach back to "
          .. "2021, and it is the only part of the collection genuinely older than "
          .. "this window." },

        { kind = "h", text = "The shape of fourteen weeks" },

        { kind = "spans", from = "2025-09", to = "2025-12",
          caption = "Each bar runs from the first day one of a project's files was "
            .. "written in this window to the last. Bars are placed by month, so a "
            .. "project confined to a few days shows as a single block. A bar is not "
            .. "a claim that work happened across all of it — only that something was "
            .. "written at each end.",
          items = {
            { name = "cloudtop-contest",        first = "2025-09", last = "2025-09", count = 8 },
            { name = "words-pdf",               first = "2025-09", last = "2025-12", count = 106 },
            { name = "neocities-modernization", first = "2025-09", last = "2025-12", count = 158 },
            { name = "magic-rumble",            first = "2025-09", last = "2025-09", count = 21 },
            { name = "factory-war",             first = "2025-09", last = "2025-09", count = 1 },
            { name = "adventure-hero-quest",    first = "2025-09", last = "2025-09", count = 10 },
            { name = "links-awakening",         first = "2025-09", last = "2025-09", count = 2 },
            { name = "console-demakes",         first = "2025-09", last = "2025-09", count = 24 },
            { name = "handheld-office",         first = "2025-09", last = "2025-11", count = 179 },
            { name = "games/galactic-battlegrounds", first = "2025-09", last = "2025-09", count = 1 },
            { name = "scripts",                 first = "2025-10", last = "2025-12", count = 8 },
            { name = "RPG-autobattler",         first = "2025-10", last = "2025-10", count = 143 },
            { name = "healer-td",               first = "2025-10", last = "2025-10", count = 21 },
            { name = "progress-ii",             first = "2025-10", last = "2025-12", count = 101 },
            { name = "continual-co-operation",  first = "2025-11", last = "2025-11", count = 19 },
            { name = "risc-v-university",       first = "2025-11", last = "2025-11", count = 28 },
            { name = "ai-playground",           first = "2025-11", last = "2025-11", count = 42 },
            { name = "resume-generation",       first = "2025-11", last = "2025-11", count = 3 },
            { name = "games/gameboy-color-rpg", first = "2025-11", last = "2025-11", count = 20 },
            { name = "dark-volcano",            first = "2025-11", last = "2025-12", count = 39 },
            { name = "adroit",                  first = "2025-12", last = "2025-12", count = 50 },
            { name = "delta-version",           first = "2025-12", last = "2025-12", count = 37 },
          } },

        { kind = "findings", items = {
          "**Ten projects appear in September alone**, most of them lasting days. A "
            .. "contest entry, a card game, a factory game, an adventure game, a "
            .. "Zelda project, a console-demake toolchain — several are a single file "
            .. "each. **This is a month of starting things**, and the ones that last "
            .. "are not obviously the ones that got the most attention that month.",
          "**The largest single project in the window is a text editor for a handheld "
            .. "games console** — a Game Boy Advance-styled editor with hierarchical "
            .. "input and networked assistance — at 179 files across September to "
            .. "November. It is not one of the projects the later reports follow, "
            .. "which is worth stating plainly: **the biggest thing here went quiet.**",
          "**Two projects run the whole window and keep running for another nine "
            .. "months**: the poetry website at 158 files and the poetry book at 106. "
            .. "They are the two that read the shared notes vault, and they appear in "
            .. "every report in this series.",
          "**October and November are bursts, not a stream.** Three weeks in October "
            .. "produce eight, three and five files; the week of the 20th produces "
            .. "175. An auto-battler contributes 143 of them in a single day, 22 "
            .. "October. A tower-defence game contributes 21 on the same day.",
          "**One week produced nothing that survives** — 24 to 30 November. It is the "
            .. "only silent week in the window, and it sits directly before the run "
            .. "that ends in version control.",
        } },

        { kind = "h", text = "7 December, 22:53 · the repository is decided on" },

        { kind = "p", text = "Eight ticket files are written in seven minutes on a "
          .. "Sunday night, in a project that did not exist that morning. Their names "
          .. "are the argument: comprehensive git repository setup, discover and "
          .. "analyse gitignore files, design a unification strategy, implement "
          .. "pattern processing, a project discovery system, a ticket distribution "
          .. "engine." },
        { kind = "pull", text = "The tool for managing a collection of projects was "
          .. "specified eight days before the collection entered version control, in "
          .. "one sitting, late at night." },
        { kind = "p", text = "It is the clearest thing the timestamps say. **Nothing "
          .. "forces a repository until the number of things exceeds what one person "
          .. "can hold**, and this window puts that threshold in the first week of "
          .. "December 2025, after fourteen weeks and twenty-four projects." },

        { kind = "h", text = "14 December, 23:20 · the last night" },

        { kind = "p", text = "The final two files written before the founding commit "
          .. "belong to the poetry website: a document weighing two ways of running "
          .. "work in parallel against each other, and a ticket to build graphics-card "
          .. "compute infrastructure. **The last thing done before the record begins "
          .. "is a decision about how to make something faster** — and the graphics-"
          .. "card path it proposes is not actually built until March, in *167 of "
          .. "167*, three months and a whole repository later." },
      },
    },
    -- }}}

    -- {{{ the limits
    {
      id = "limits", name = "what this cannot tell you", short = "the limits",
      commits = 0, slug = "four caveats",
      identity = "Everything above is inferred from when files were last written. "
        .. "Four things that does not record, each bending the picture in a known "
        .. "direction.",
      blocks = {
        { kind = "pull", text = "A modification time is not a record of work. It is a "
          .. "record of the last time a file was written — and only for the files that "
          .. "still exist." },
        { kind = "findings", items = {
          "**It only counts survivors.** A file written in September and deleted in "
            .. "October leaves nothing at all. Every count here is a floor, and the "
            .. "earlier weeks are floored harder than the later ones.",
          "**It records the last touch, not the first.** A document started in "
            .. "September and revised in December appears only in December. So the "
            .. "early weeks are undercounted by exactly the amount of work that was "
            .. "later returned to — which is to say, by the work that mattered most.",
          "**Any bulk operation overwrites it.** A copy, a restore or a sync stamps "
            .. "its own moment onto everything it touches, which would turn one "
            .. "afternoon of copying into a fake week of work. The test for it is to "
            .. "count distinct timestamps against total files per month: a bulk copy "
            .. "gives thousands of files the same second, editing gives each its own. "
            .. "**Inside this window the four months score 0.76, 0.83, 0.83 and "
            .. "0.73** — roughly three files in four written at their own moment. Two "
            .. "months elsewhere in the collection score 0.23 and 0.25 and are "
            .. "excluded, which is part of why this window starts where it does.",
          "**It says nothing about what was done.** This page can say that 143 files "
            .. "appeared in an auto-battler on 22 October. It cannot say what any of "
            .. "them contained, whether the day went well, or what was decided. Every "
            .. "other page in this directory can, because somebody wrote it down.",
        } },
        { kind = "p", text = "**And unlike every other page here, this one cannot be "
          .. "regenerated.** It is built from live filesystem state rather than "
          .. "history. A single checkout, restore or sync would rewrite the evidence "
          .. "and make this page wrong without changing one commit." },
      },
    },
    -- }}}

  },


  -- {{{ open
  open = {
    { project = "the fourteen weeks", state = "Unrecorded", tone = "blocked",
      waiting = "**No conversations, commit messages or progress notes exist from "
        .. "this period.** What any of these twenty-four projects was for, what was "
        .. "decided, what was abandoned and why — none of it is written anywhere the "
        .. "repository can reach. The files are the only witnesses and they say when "
        .. "rather than what." },
    { project = "handheld-office", state = "Went quiet", tone = "open",
      waiting = "179 files across three months, the largest project in the window, "
        .. "and it does not appear in any later report. Whether it was finished, "
        .. "abandoned or merely paused is not answerable from here." },
    { project = "the notes vault", state = "Outside", tone = "open",
      waiting = "The shared notes synced into several projects are older than this "
        .. "window and live outside the repository. Their real history is on another "
        .. "disk and would answer more than anything measurable here." },
    { project = "the silent week", state = "Ambiguous", tone = "open",
      waiting = "24 to 30 November produced nothing that survives. Whether that was a "
        .. "week off or a week whose output was deleted **cannot be settled by this "
        .. "method**." },
  },
  -- }}}

  -- {{{ tree
  tree = {
    { kind = "p", text = "Everything on this page was measured by listing the founding "
      .. "commit's file tree, keeping the paths that still exist on disk, reading "
      .. "their modification times, and filtering as the introduction describes. It "
      .. "reads the working tree and the git index and changes neither." },
    { kind = "p", text = "The filtering is worth re-running rather than trusting, and "
      .. "so is the check that separates editing from copying: for each month, count "
      .. "distinct timestamps against total files. Inside this window every month "
      .. "passes. Two months elsewhere in the collection — October 2021 and May 2024 "
      .. "— fail it badly, which is part of why this window starts where it does." },
  },
  -- }}}

}
