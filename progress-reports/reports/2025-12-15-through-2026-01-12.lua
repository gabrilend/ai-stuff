-- Part 2: 15 December 2025 through 12 January 2026.

return {

  part = 2,
  slug_name = "the-founding",
  title = "29,157 Files",
  eyebrow = "Part 2 · 15 December 2025 – 12 January 2026",
  compiled = "compiled 6 Sep 2026",
  dek = "Everything enters version control in one commit. Two days later the "
    .. "repository has a program that splits an issue into sub-issues and hands "
    .. "them to an assistant, and a rule about fallbacks that the next eight "
    .. "months keep applying.",

  totals = {
    { value = "597", label = "issues written" },
    { value = "261", label = "completed" },
    { value = "7", label = "projects" },
  },

  -- {{{ days
  days = {
    { label = "15", value = 1, emphasis = true, month = "December" },
    { label = "16", value = 46, emphasis = true },
    { label = "17", value = 50, emphasis = true },
    { label = "18", value = 17 },
    { label = "19", value = 2 },
    { label = "20", value = 3 },
    { label = "21", value = 18 },
    { label = "",   value = 0 },
    { label = "23", value = 46 },
    { label = "",   value = 0 },
    { label = "25", value = 12 },
    { label = "26", value = 6 },
    { label = "27", value = 55, emphasis = true },
    { label = "",   value = 0 },
    { label = "29", value = 23 },
    { label = "30", value = 12 },
    { label = "31", value = 30 },
    { label = "01", value = 9 },
    { label = "02", value = 14 },
    { label = "",   value = 0 },
    { label = "04", value = 34 },
    { label = "05", value = 4 },
    { label = "",   value = 0 },
    { label = "07", value = 22, emphasis = true },
    { label = "08", value = 22 },
    { label = "09", value = 17 },
    { label = "10", value = 13 },
    { label = "11", value = 4 },
    { label = "12", value = 8, month = "January" },
  },
  chart_alt = "Commits per day from 15 December 2025 to 12 January 2026: one on the "
    .. "15th, then 46 and 50, a peak of 55 on the 27th, and a steady run through the "
    .. "new year ending at 8 on 12 January.",
  chart_caption = "Commits per day. Four blank days in twenty-nine, Christmas Day "
    .. "not among them.",
  -- }}}

  -- {{{ intro
  intro = {
    { kind = "lead", text = "The window opens with the repository's first commit and "
      .. "closes on 12 January, four days before the next stage begins." },
    { kind = "p", text = "**The first commit is 29,157 files and 10,894,824 lines**, "
      .. "titled *Initial commit: AI project collection*. It is the fourteen weeks of "
      .. "Part 1 arriving at once, plus every library those projects had copied into "
      .. "themselves. Ten weeks later, 2,349 of those library files come back out "
      .. "again in favour of install scripts — the two events are the same decision "
      .. "made twice, once by default and once deliberately." },
    { kind = "p", text = "After that, two threads run: the Warcraft III engine takes "
      .. "357 of the window's 597 new issue files, and the tooling that manages the "
      .. "repository takes 70." },
  },
  -- }}}

  work_caption = "Issue files, 15 December – 12 January",
  -- {{{ work
  work = {
    { name = "world-edit-to-execute",   commits = 357, added = 201, removed = 0 },
    { name = "neocities-modernization", commits = 65,  added = 31,  removed = 0 },
    { name = "translation-layer-wow-chat", commits = 62, added = 0, removed = 0 },
    { name = "delta-version",           commits = 38,  added = 25,  removed = 0 },
    { name = "scripts",                 commits = 32,  added = 4,   removed = 0 },
    { name = "ao3-source-code-import",  commits = 22,  added = 0,   removed = 0 },
    { name = "my-libs",                 commits = 10,  added = 0,   removed = 0 },
  },
  -- }}}
  work_note = {
    { kind = "p", text = "Columns are issue files written and completed. These "
      .. "exclude the founding commit, which imported issue files rather than writing "
      .. "them." },
  },

  projects_caption = "What happened",
  projects = {

    -- {{{ the tooling
    {
      id = "tooling", name = "the tooling", short = "the tooling",
      commits = 70, slug = "70 issues written, 29 completed",
      identity = "The issue-splitter and the repository meta-project, both built on "
        .. "days two and three.",
      stats = {
        { key = "Started",  value = "day 2" },
        { key = "Guide symlinked into", value = "20", note = "projects" },
        { key = "Fallback lines deleted", value = "95" },
      },
      blocks = {
        { kind = "p", text = "**The issue-splitter is the first real program in the "
          .. "repository.** It takes a large ticket and breaks it into sub-issues. "
          .. "Over 16 December it grows a queue, a producer, a streaming process that "
          .. "emits sub-issues as they are derived rather than at the end, a parallel "
          .. "processing loop, and flags to configure all of it — five sub-issues "
          .. "closed in order, in one day." },
        { kind = "p", text = "**The same day it gains a flag that pipes an issue file "
          .. "to an assistant on the command line and asks it to implement the steps "
          .. "described there**, with a dry-run mode that prints the prompt instead "
          .. "and a confirmation required unless explicitly overridden. Day two of the "
          .. "repository's existence." },
        { kind = "p", text = "Around it a terminal-interface library is assembled "
          .. "component by component — a core, checkboxes, a multi-state toggle, text "
          .. "inputs, menu navigation — then integrated back into the splitter so the "
          .. "same work can be driven by hand. Over the following day it gains numeric "
          .. "jump, repeated-digit selection for long menus, shift-digit to go back a "
          .. "tier, and inline-editable flag fields." },

        { kind = "thread", name = "Fallbacks hide bugs",
          text = "A simpler non-graphical mode existed as a fallback for when the "
            .. "interface library was unavailable. **Ninety-five lines of it were "
            .. "deleted and replaced with an error naming what is missing**, and the "
            .. "commit states the reason: *fallbacks hide bugs — errors should be "
            .. "clear and intentional*. It is standing policy in the author's "
            .. "conventions rather than a discovery, and the later parts record where "
            .. "applying it caught something." },

        { kind = "p", text = "**On 17 December a program is written that reads a "
          .. "project's git log and produces a readable file presenting the "
          .. "development as a chronological story** — oldest commit first, *like "
          .. "reading a book*, full messages preserved, with filters for date range "
          .. "and completeness. It is the direct ancestor of the document you are "
          .. "reading, nine months earlier, as a shell script." },

        { kind = "p", text = "Also built: a viewer that gathers every project's vision "
          .. "document into one place, a project-detection tool for importing outside "
          .. "work into the collection, and on 4 January a maintainer's guide "
          .. "**symlinked into the documentation folder of all twenty projects**, so "
          .. "it is reachable from wherever you are standing." },

        { kind = "p", text = "One bug fixed here on 16 December comes back: **a "
          .. "counter written as a post-increment exits a script that aborts on "
          .. "failure**, because incrementing from zero returns the old value and the "
          .. "shell reads zero as failure. The identical bug is fixed again in the "
          .. "history reconstructor on 17 February, in a different script." },

        { kind = "transcripts", project = "delta-version", items = {
          { file = "dec-15-25.md", label = "15 Dec", agents = 6 },
          { file = "dec-16-25.md", label = "16 Dec" },
          { file = "dec-17-25.md", label = "17 Dec", agents = 11 },
          { file = "dec-18-25.md", label = "18 Dec", agents = 1 },
          { file = "dec-21-25.md", label = "21 Dec", agents = 2 },
        } },
      },
    },
    -- }}}

    -- {{{ world-edit-to-execute
    {
      id = "wete", name = "world-edit-to-execute", short = "world-edit",
      commits = 357, slug = "357 issues written, 201 completed",
      identity = "Nine map file formats parsed, a runtime built on top of them, and "
        .. "a second architecture designed and archived in one day.",
      stats = {
        { key = "Formats parsed", value = "9" },
        { key = "Tick rate", value = "62.5", note = "Hz" },
        { key = "Design archived", value = "2,700", note = "lines" },
      },
      blocks = {
        { kind = "p", text = "The first three days are parsers, one format at a time: "
          .. "the archive container, the map information file, the trigger strings, "
          .. "the terrain, the units and buildings with their item drops and hero "
          .. "data, the doodads, the regions, the cameras, the sounds. Then a unified "
          .. "map structure they all feed, a tool that dumps a map's metadata, and an "
          .. "integration test." },
        { kind = "p", text = "**One parser needed a 1990s compression scheme "
          .. "implemented from scratch** — PKWARE DCL, used inside the archives — and "
          .. "its limitation was documented and cross-referenced two days before the "
          .. "implementation landed." },
        { kind = "p", text = "By the new year there is a game loop with a threading "
          .. "architecture, a death and resurrection system with corpses that decay "
          .. "and a ghost form for reviving heroes, and an attribute system mapping "
          .. "between two games' notions of a statistic. **The threading runs at 62.5 "
          .. "ticks per second — one every sixteen milliseconds — because that is the "
          .. "rate the original game used**, and a custom map's scripts are written "
          .. "against it." },

        { kind = "h", text = "7 January · the pivot" },

        { kind = "p", text = "A second architecture had been designed alongside the "
          .. "first: integrating with AzerothCore, an open-source World of Warcraft "
          .. "server, so the engine could host that game's content too. Five "
          .. "documents, about 2,700 lines — integration architecture, client "
          .. "architecture, data conversion pipeline, a bridge for custom abilities, "
          .. "and a phase reorganisation to fit it all in." },
        { kind = "pull", text = "All of it was archived on 7 January and the project "
          .. "returned to being a pure Warcraft III engine, on the stated reasoning "
          .. "that a game-engine reimplementation follows the legal precedent set by "
          .. "console emulators, and that attaching somebody else's live server to it "
          .. "is a different question with a different answer." },
        { kind = "p", text = "The 2,700 lines moved to a dated archive folder with a "
          .. "README explaining the context, and a postmortem was written beside the "
          .. "replacement design. The profession system built for the abandoned "
          .. "direction — gathering, crafting, recipes, cooldowns — was archived the "
          .. "same way rather than reverted." },

        { kind = "thread", name = "Replaced designs are filed, not deleted",
          text = "This is the earliest instance. The city game does it with six "
            .. "tickets in September, each marked with what replaced it and why; the "
            .. "handheld operating system does it with twenty-two in July, moved to a "
            .. "superseded folder with a file mapping each old one to its "
            .. "replacement. **Nothing in the year is quietly removed.**" },

        { kind = "transcripts", project = "world-edit-to-execute", items = {
          { file = "jan-7-26.md", label = "7 Jan", agents = 296 },
        } },
      },
    },
    -- }}}

    -- {{{ neocities
    {
      id = "neocities", name = "neocities-modernization", short = "neocities",
      commits = 65, slug = "65 issues written, 31 completed",
      identity = "",
      blocks = {
        { kind = "p", text = "Sixty-five issue files and thirty-one completed, spread "
          .. "thin across the window rather than concentrated — a few commits most "
          .. "days from 17 December, with the heavier runs on 8 through 11 January. "
          .. "It is the project that gets attention in the gaps around whatever else "
          .. "is being built, which is the shape it keeps for the next nine months." },
        { kind = "p", text = "The window's last commit is titled, in full, "
          .. "*lost-and-found*, with no message body — a day's stray work swept up and "
          .. "named honestly rather than reconstructed into something tidier." },
      },
    },
    -- }}}

  },

  -- {{{ open
  open = {
    { project = "world-edit-to-execute", state = "Archived", tone = "built",
      waiting = "The integration with an outside game server is closed deliberately, "
        .. "with 2,700 lines of design preserved and a postmortem written. Listed "
        .. "because it is the decision the rest of the project is measured against." },
    { project = "world-edit-to-execute", state = "Sketched", tone = "open",
      waiting = "A matchmaking server split into nine sub-issues on 8 January, and a "
        .. "world editor phase created on the 2nd. Neither built. The project goes "
        .. "quiet after this window and does not return substantially until February." },
    { project = "the tooling", state = "Specification", tone = "open",
      waiting = "A commit history viewer was specified and not implemented. The "
        .. "narrative history generator was implemented." },
  },
  -- }}}

  -- {{{ tree
  tree = {
    { kind = "p", text = "One commit of 29,157 files established the layout every "
      .. "later part describes — a folder per project, each with its own issues, "
      .. "docs, notes, src and libs. Two things in it were later undone on purpose: "
      .. "the vendored libraries, removed in Part 3, and the practice of one commit "
      .. "touching forty projects at once, which the commit gates in Part 9 make "
      .. "difficult deliberately." },
  },
  -- }}}
}
